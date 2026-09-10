from __future__ import annotations

import base64
from dataclasses import dataclass, field
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from typing import Callable
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen
import webbrowser


BASE_URL = os.getenv("BORUTA_OAUTH_BASE_URL", "http://localhost:8080").rstrip("/")
CLIENT_ID = os.getenv("BORUTA_AGENT_CHAT_CLIENT_ID", "00000000-0000-0000-0000-000000000001")
CLIENT_SECRET = os.getenv("BORUTA_AGENT_CHAT_CLIENT_SECRET", "")
CLIENT_PRIVATE_KEY_PATH = os.getenv(
    "BORUTA_AGENT_CHAT_PRIVATE_KEY_PATH",
    "/tmp/boruta-agent-chat-private-key.pem",
)
CLIENT_PUBLIC_JWK = os.getenv("BORUTA_AGENT_CHAT_PUBLIC_JWK")
REDIRECT_URI = os.getenv("BORUTA_AGENT_CHAT_REDIRECT_URI", "http://127.0.0.1:8765/oauth-callback")
CALLBACK_HOST = os.getenv("BORUTA_AGENT_CHAT_CALLBACK_HOST")
OPEN_BROWSER = os.getenv("BORUTA_AGENT_CHAT_OPEN_BROWSER", "true").lower() not in (
    "0",
    "false",
    "no",
)
WALLET_URL = os.getenv("BORUTA_AGENT_CHAT_WALLET_URL", f"{BASE_URL}/accounts/wallet")
TOKEN_TARGET = os.getenv("BORUTA_AGENT_CHAT_TOKEN_TARGET", f"{BASE_URL}/oauth/token")
TOKEN_TIMEOUT_SECONDS = float(os.getenv("BORUTA_AGENT_CHAT_TOKEN_TIMEOUT", "5"))
INITIAL_CODE_TIMEOUT_SECONDS = float(os.getenv("BORUTA_AGENT_CHAT_INITIAL_CODE_TIMEOUT", "300"))


@dataclass
class Message:
    sender: str
    recipient: str
    content: str


@dataclass(frozen=True)
class AgentKeyPair:
    key_id: str


class DerReader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def read_tlv(self, expected_tag: int | None = None) -> tuple[int, bytes]:
        tag = self.data[self.offset]
        self.offset += 1
        if expected_tag is not None and tag != expected_tag:
            raise RuntimeError(f"unexpected DER tag 0x{tag:02x}, expected 0x{expected_tag:02x}")

        length = self.data[self.offset]
        self.offset += 1
        if length & 0x80:
            length_size = length & 0x7F
            length = int.from_bytes(self.data[self.offset : self.offset + length_size], "big")
            self.offset += length_size

        value = self.data[self.offset : self.offset + length]
        self.offset += length
        return tag, value


@dataclass(frozen=True)
class ClientKeySigner:
    private_key_path: str
    jwk: dict[str, str]

    @classmethod
    def from_env(cls) -> "ClientKeySigner":
        ensure_private_key(CLIENT_PRIVATE_KEY_PATH)

        jwk = json.loads(CLIENT_PUBLIC_JWK) if CLIENT_PUBLIC_JWK else rsa_public_jwk(CLIENT_PRIVATE_KEY_PATH)
        jwk.setdefault("alg", "RS512")
        return cls(private_key_path=CLIENT_PRIVATE_KEY_PATH, jwk=jwk)

    def id_token(self, key_id: str) -> str:
        now = int(time.time())
        header = {
            "alg": "RS512",
            "typ": "JWT",
            "kid": key_id,
            "jwk": self.jwk,
        }
        payload = {
            "sub": key_id,
            "iat": now,
            "exp": now + 3600,
        }
        signing_input = f"{base64_url_json(header)}.{base64_url_json(payload)}"
        signature = sign_rs512(self.private_key_path, signing_input.encode("ascii"))

        return f"{signing_input}.{base64_url(signature)}"


@dataclass
class BrowserInitialCodeClient:
    base_url: str = BASE_URL
    client_id: str = CLIENT_ID
    redirect_uri: str = REDIRECT_URI
    wallet_url: str = WALLET_URL
    timeout: float = INITIAL_CODE_TIMEOUT_SECONDS

    def issue_initial_authorization_code(self, previous_authorization_code: str | None = None) -> str:
        return self.issue_browser_authorization_code(
            response_type="id_token",
            previous_authorization_code=previous_authorization_code,
            request_name="id_token presentation",
        )

    def issue_authorization_code_request(self, previous_authorization_code: str | None = None) -> str:
        return self.issue_browser_authorization_code(
            response_type="code",
            previous_authorization_code=previous_authorization_code,
            request_name="authorization code request",
            scope="email",
        )

    def issue_browser_authorization_code(
        self,
        response_type: str,
        previous_authorization_code: str | None = None,
        request_name: str = "browser authorization request",
        scope: str = ""
    ) -> str:
        callback = CallbackState(wallet_url=self.wallet_url)
        server = callback_server(self.redirect_uri, callback)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()

        authorize_params = {
            'client_id': self.client_id,
            'redirect_uri': self.redirect_uri,
            'response_type': response_type,
            'prompt': 'login',
            'scope': scope,
            'state': 'agent-chat',
        }
        if response_type != "code":
            authorize_params["client_metadata"] = "{}"
        if previous_authorization_code:
            authorize_params["code"] = previous_authorization_code

        authorize_url = f"{self.base_url}/oauth/authorize?{urlencode(authorize_params)}"

        if previous_authorization_code:
            print(f"[browser -> chained {request_name}]")
        else:
            print(f"[browser -> first {request_name}]")
        if OPEN_BROWSER:
            print(f"Opening {authorize_url}")
            webbrowser.open(authorize_url)
        else:
            print("Open this URL in your host browser:")
            print(authorize_url)
        print(f"Complete the {request_name}. Waiting for the final redirect code...")

        try:
            return callback.wait_for_code(self.timeout)
        finally:
            server.shutdown()
            server.server_close()


@dataclass
class CodeChainTokenClient:
    signer: ClientKeySigner
    token_target: str = TOKEN_TARGET
    client_id: str = CLIENT_ID
    client_secret: str = CLIENT_SECRET
    timeout: float = TOKEN_TIMEOUT_SECONDS

    def issue_authorization_code(
        self,
        message: Message,
        key_pair: AgentKeyPair,
        previous_authorization_code: str,
    ) -> str:
        parameters = {
            "client_id": self.client_id,
            "grant_type": "code_chain",
            "id_token": self.signer.id_token(key_pair.key_id),
            "authorization_code": previous_authorization_code,
        }
        if self.client_secret:
            parameters["client_secret"] = self.client_secret

        request_body = urlencode(parameters).encode("utf-8")
        request = Request(
            self.token_target,
            data=request_body,
            headers={"content-type": "application/x-www-form-urlencoded"},
            method="POST",
        )

        try:
            with urlopen(request, timeout=self.timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"code_chain token call failed for {key_pair.key_id}: {error} {body}"
            ) from error
        except (URLError, TimeoutError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"code_chain token call failed for {key_pair.key_id}: {error}"
            ) from error

        authorization_code = payload.get("authorization_code")
        print(payload)
        if not isinstance(authorization_code, str) or not authorization_code:
            raise RuntimeError(
                f"code_chain token response missing authorization_code for {key_pair.key_id}"
            )

        return authorization_code


@dataclass
class Agent:
    name: str
    instructions: str
    handler: Callable[["Agent", list[Message]], Message]
    key_pair: AgentKeyPair
    token_client: CodeChainTokenClient
    inbox: list[Message] = field(default_factory=list)
    authorization_codes: list[str] = field(default_factory=list)

    def receive(self, message: Message, previous_authorization_code: str) -> None:
        authorization_code = self.token_client.issue_authorization_code(
            message,
            self.key_pair,
            previous_authorization_code,
        )
        self.authorization_codes.append(authorization_code)
        print(f"[code_chain -> {self.name}]")
        print(authorization_code)
        self.inbox.append(message)

    def receive_presentation(self, message: Message, authorization_code: str) -> None:
        self.authorization_codes.append(authorization_code)
        print(f"[id_token presentation -> {self.name}]")
        print(authorization_code)
        self.inbox.append(message)

    def receive_authorization_code_request(self, message: Message, authorization_code: str) -> None:
        self.authorization_codes.append(authorization_code)
        print(f"[authorization code request -> {self.name}]")
        print(authorization_code)
        self.inbox.append(message)

    def receive_local(self, message: Message) -> None:
        print(f"[local -> {self.name}]")
        self.inbox.append(message)

    def respond(self, transcript: list[Message]) -> Message:
        return self.handler(self, transcript)


class AgentRoom:
    def __init__(self, agents: list[Agent], initial_code_client: BrowserInitialCodeClient) -> None:
        self.agents = {agent.name: agent for agent in agents}
        self.initial_code_client = initial_code_client
        self.transcript: list[Message] = []
        self.presentation_recipients = {"planner"}
        self.authorization_code_request_recipients = {"writer"}

    def send(self, message: Message) -> None:
        self.transcript.append(message)
        if message.recipient in self.agents:
            previous_code = self.latest_authorization_code(message.sender)
            if previous_code is None:
                if message.recipient in self.presentation_recipients:
                    authorization_code = self.initial_code_client.issue_initial_authorization_code()
                    self.agents[message.recipient].receive_presentation(message, authorization_code)
                elif message.recipient in self.authorization_code_request_recipients:
                    authorization_code = self.initial_code_client.issue_authorization_code_request()
                    self.agents[message.recipient].receive_authorization_code_request(message, authorization_code)
                else:
                    self.agents[message.recipient].receive(message)
            elif message.recipient in self.presentation_recipients:
                authorization_code = self.initial_code_client.issue_initial_authorization_code(previous_code)
                self.agents[message.recipient].receive_presentation(message, authorization_code)
            elif message.recipient in self.authorization_code_request_recipients:
                authorization_code = self.initial_code_client.issue_authorization_code_request(previous_code)
                self.agents[message.recipient].receive_authorization_code_request(message, authorization_code)
            else:
                self.agents[message.recipient].receive(message, previous_code)

    def ask(self, sender: str, recipient: str, content: str) -> None:
        self.send(Message(sender=sender, recipient=recipient, content=content))

    def run_round(self, agent_name: str) -> Message:
        message = self.agents[agent_name].respond(self.transcript)
        self.send(message)
        return message

    def run_parallel(self, agent_names: list[str]) -> list[Message]:
        messages = [
            self.agents[agent_name].respond(self.transcript)
            for agent_name in agent_names
        ]
        for message in messages:
            self.send(message)
        return messages

    def latest_authorization_code(self, agent_name: str) -> str | None:
        agent = self.agents.get(agent_name)
        if agent is None or not agent.authorization_codes:
            return None

        return agent.authorization_codes[-1]

    def print_transcript(self) -> None:
        for message in self.transcript:
            print(f"\n[{message.sender} -> {message.recipient}]")
            print(message.content)


class CallbackState:
    def __init__(self, wallet_url: str) -> None:
        self.wallet_url = wallet_url
        self.condition = threading.Condition()
        self.code: str | None = None
        self.error: str | None = None

    def wait_for_code(self, timeout: float) -> str:
        deadline = time.monotonic() + timeout
        with self.condition:
            while self.code is None and self.error is None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                self.condition.wait(remaining)

            if self.code:
                return self.code
            if self.error:
                raise RuntimeError(self.error)

        raise TimeoutError("timed out waiting for browser authorization callback")

    def set_code(self, code: str) -> None:
        with self.condition:
            self.code = code
            self.condition.notify_all()

    def set_error(self, error: str) -> None:
        with self.condition:
            self.error = error
            self.condition.notify_all()


def callback_server(redirect_uri: str, callback: CallbackState) -> HTTPServer:
    parsed = urlparse(redirect_uri)
    if parsed.scheme not in ("http", "https") or not parsed.hostname or not parsed.port:
        raise RuntimeError(
            "BORUTA_AGENT_CHAT_REDIRECT_URI must include an http host and explicit port"
        )

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            query = parse_qs(urlparse(self.path).query)
            code = first(query, "code")
            error = first(query, "error_description") or first(query, "error")

            if code:
                callback.set_code(code)
                self.respond_html("Authorization code received. You can close this tab.")
                return

            if error:
                callback.set_error(error)
                self.respond_html(f"Authorization failed: {error}", status=400)
                return

            wallet_target = f"{callback.wallet_url}?{urlparse(self.path).query}"
            self.send_response(302)
            self.send_header("Location", wallet_target)
            self.end_headers()

        def log_message(self, _format: str, *_args: object) -> None:
            return

        def respond_html(self, body: str, status: int = 200) -> None:
            content = (
                "<!doctype html><meta charset='utf-8'>"
                f"<title>Boruta agent chat</title><p>{body}</p>"
            ).encode("utf-8")
            self.send_response(status)
            self.send_header("content-type", "text/html; charset=utf-8")
            self.send_header("content-length", str(len(content)))
            self.end_headers()
            self.wfile.write(content)

    return HTTPServer((CALLBACK_HOST or parsed.hostname, parsed.port), CallbackHandler)


def first(values: dict[str, list[str]], key: str) -> str | None:
    value = values.get(key)
    if not value:
        return None
    return value[0]


def latest_user_request(transcript: list[Message]) -> str:
    for message in reversed(transcript):
        if message.sender == "user":
            return message.content
    return ""


def latest_from(
    transcript: list[Message],
    sender: str,
    recipient: str | None = None,
) -> str:
    for message in reversed(transcript):
        if message.sender == sender and (
            recipient is None or message.recipient == recipient
        ):
            return message.content
    return ""


def local_writer_reply(request: str, merge: str, critique: str) -> str:
    return (
        f"Final response for: {request}\n\n"
        "The workflow starts with a browser SIOPv2 id_token presentation, "
        "adds a browser authorization code request before the final writer, "
        "then continues with code_chain calls at agent handoffs.\n\n"
        f"Merge output:\n{merge}\n\n"
        f"Critic output:\n{critique}"
    )


def base64_url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def base64_url_json(value: object) -> str:
    return base64_url(json.dumps(value, separators=(",", ":")).encode("utf-8"))


def sign_rs512(private_key_path: str, signing_input: bytes) -> bytes:
    result = subprocess.run(
        ["openssl", "dgst", "-sha512", "-sign", private_key_path],
        input=signing_input,
        capture_output=True,
        check=True,
    )
    return result.stdout


def ensure_private_key(private_key_path: str) -> None:
    path = Path(private_key_path)
    if path.exists():
        return

    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            "openssl",
            "genpkey",
            "-algorithm",
            "RSA",
            "-pkeyopt",
            "rsa_keygen_bits:2048",
            "-out",
            str(path),
        ],
        capture_output=True,
        check=True,
    )
    path.chmod(0o600)


def rsa_public_jwk(private_key_path: str) -> dict[str, str]:
    result = subprocess.run(
        ["openssl", "pkey", "-in", private_key_path, "-pubout", "-outform", "DER"],
        capture_output=True,
        check=True,
    )
    return rsa_spki_der_to_jwk(result.stdout)


def rsa_spki_der_to_jwk(der: bytes) -> dict[str, str]:
    spki = DerReader(der)
    _, spki_body = spki.read_tlv(0x30)
    spki_reader = DerReader(spki_body)
    spki_reader.read_tlv(0x30)
    _, subject_public_key = spki_reader.read_tlv(0x03)

    rsa_public_key = subject_public_key[1:]
    rsa_reader = DerReader(rsa_public_key)
    _, rsa_body = rsa_reader.read_tlv(0x30)
    rsa_body_reader = DerReader(rsa_body)
    _, modulus = rsa_body_reader.read_tlv(0x02)
    _, exponent = rsa_body_reader.read_tlv(0x02)

    return {
        "kty": "RSA",
        "n": base64_url(unsigned_integer(modulus)),
        "e": base64_url(unsigned_integer(exponent)),
        "alg": "RS512",
    }


def unsigned_integer(value: bytes) -> bytes:
    while len(value) > 1 and value[0] == 0:
        value = value[1:]
    return value


def agent_key_pair(agent_name: str) -> AgentKeyPair:
    return AgentKeyPair(
        key_id=f"{agent_name}-key",
    )


def agent(
    name: str,
    instructions: str,
    handler: Callable[[Agent, list[Message]], Message],
    token_client: CodeChainTokenClient,
) -> Agent:
    return Agent(
        name=name,
        instructions=instructions,
        handler=handler,
        key_pair=agent_key_pair(name),
        token_client=token_client,
    )


def planner_handler(agent: Agent, transcript: list[Message]) -> Message:
    request = latest_user_request(transcript)
    plan = (
        f"Goal: {request}\n"
        "Plan:\n"
        "1. Use the browser-presented id_token code as the starting proof.\n"
        "2. Fan out the same plan to researcher, security, and implementer.\n"
        "3. Merge the parallel outputs with normal code_chain calls.\n"
        "4. Send the synthesis to the critic with a normal code_chain handoff.\n"
        "5. Ask the writer to summarize the merged and reviewed result after an authorization code request."
    )
    return Message(sender=agent.name, recipient="all", content=plan)


def researcher_handler(agent: Agent, transcript: list[Message]) -> Message:
    plan = latest_from(transcript, "planner", "all")
    research = (
        "Research notes:\n"
        "- Keep the workflow local and deterministic.\n"
        "- Preserve the receive-time code_chain call for every agent handoff.\n"
        "- Make the transcript show distinct agent responsibilities.\n"
        "- Start from the code created by the browser id_token presentation.\n\n"
        f"Plan reviewed:\n{plan}"
    )
    return Message(sender=agent.name, recipient="merger", content=research)


def security_handler(agent: Agent, transcript: list[Message]) -> Message:
    plan = latest_from(transcript, "planner", "all")
    security_review = (
        "Security branch:\n"
        "- The first code is issued only after the wallet posts an id_token.\n"
        "- The writer receives a browser authorization code request before final response generation.\n"
        "- Every later receiving agent mints its own id_token.\n"
        "- Each receive call submits code_chain with the previous authorization_code.\n"
        "- Printed authorization codes make the chain observable for the example.\n\n"
        f"Plan reviewed:\n{plan}"
    )
    return Message(sender=agent.name, recipient="merger", content=security_review)


def implementer_handler(agent: Agent, transcript: list[Message]) -> Message:
    plan = latest_from(transcript, "planner", "all")
    implementation = (
        "Implementation branch:\n"
        "- Build a routed multi-agent conversation.\n"
        "- Use the browser flow once, before the planner receives the first message.\n"
        "- Run researcher, security, and implementer from the same plan snapshot.\n"
        "- Merge the branch outputs before review.\n"
        "- Use a browser authorization code request before the writer accepts the review.\n\n"
        f"Plan reviewed:\n{plan}"
    )
    return Message(sender=agent.name, recipient="merger", content=implementation)


def merger_handler(agent: Agent, transcript: list[Message]) -> Message:
    plan = latest_from(transcript, "planner", "all")
    research = latest_from(transcript, "researcher", "merger")
    security = latest_from(transcript, "security", "merger")
    implementation = latest_from(transcript, "implementer", "merger")
    merge = (
        "Merged synthesis:\n"
        "- Browser presentation established the initial authorization code.\n"
        "- Linear setup established the route and plan.\n"
        "- Parallel branches produced research, security, and implementation views.\n"
        "- The next linear stages can review and finalize one merged artifact.\n\n"
        f"Plan:\n{plan}\n\n"
        f"Research branch:\n{research}\n\n"
        f"Security branch:\n{security}\n\n"
        f"Implementation branch:\n{implementation}"
    )
    return Message(sender=agent.name, recipient="critic", content=merge)


def critic_handler(agent: Agent, transcript: list[Message]) -> Message:
    merge = latest_from(transcript, "merger", "critic")
    critique = (
        "Review:\n"
        "- The merged output shows one browser id_token presentation and the later code_chain phases.\n"
        "- The final writer handoff should include an authorization code request.\n"
        "- The final writer should include the merged result and critique.\n"
        "- The transcript should make the authorization-code chain visible.\n\n"
        f"Merged artifact reviewed:\n{merge}"
    )
    return Message(sender=agent.name, recipient="writer", content=critique)


def writer_handler(agent: Agent, transcript: list[Message]) -> Message:
    request = latest_user_request(transcript)
    merge = latest_from(transcript, "merger", "critic")
    critique = latest_from(transcript, "critic", "writer")
    answer = local_writer_reply(request, merge, critique)
    return Message(sender=agent.name, recipient="user", content=answer)


def main() -> None:
    token_client = CodeChainTokenClient(signer=ClientKeySigner.from_env())
    initial_code_client = BrowserInitialCodeClient()
    room = AgentRoom(
        initial_code_client=initial_code_client,
        agents=[
            agent("planner", "Break a user request into a practical plan.", planner_handler, token_client),
            agent("researcher", "Gather constraints and facts for another agent's plan.", researcher_handler, token_client),
            agent("security", "Review token-chain and handoff risks in a parallel branch.", security_handler, token_client),
            agent("implementer", "Turn a shared plan into concrete implementation notes.", implementer_handler, token_client),
            agent("merger", "Merge parallel branch outputs into one artifact.", merger_handler, token_client),
            agent("critic", "Find gaps and risks in another agent's plan.", critic_handler, token_client),
            agent("writer", "Write the final user-facing answer.", writer_handler, token_client),
        ],
    )

    user_prompt = os.getenv("BORUTA_AGENT_CHAT_PROMPT", "Test browser-bootstrapped agentic code-chain workflow.")
    print(
        """
+------------------------------------+
| Browser-Bootstrapped Agent Chat    |
+------------------------------------+
""".strip()
    )

    room.ask("user", "planner", user_prompt)
    room.run_round("planner")
    plan = latest_from(room.transcript, "planner", "all")
    room.ask("planner", "researcher", plan)
    room.ask("planner", "security", plan)
    room.ask("planner", "implementer", plan)
    room.run_parallel(["researcher", "security", "implementer"])
    room.run_round("merger")
    room.run_round("critic")
    room.run_round("writer")
    room.print_transcript()


if __name__ == "__main__":
    main()
