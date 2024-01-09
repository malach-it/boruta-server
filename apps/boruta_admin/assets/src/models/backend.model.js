import axios from "axios";
import { addClientErrorInterceptor } from "./utils";
import Role from './role.model'

const DEFAULT_ID = "non-existing";

const defaults = {
  id: DEFAULT_ID,
  name: null,
  roles: [],
  type: "Elixir.BorutaIdentity.Accounts.Internal",
  errors: null,
  password_hashing_alg: "argon2",
  password_hashing_opts: {},
  features: [],
  metadata_fields: [],
  federated_servers: [],
  verifiable_credentials: [],
};

const assign = {
  id: function ({ id }) {
    this.id = id;
  },
  name: function ({ name }) {
    this.name = name;
  },
  roles: function ({ roles }) {
    this.roles = roles.map((scope) => {
      return { model: new Role(scope) }
    })
  },
  type: function ({ type }) {
    this.type = type;
  },
  is_default: function ({ is_default }) {
    this.is_default = is_default;
  },
  create_default_organization: function ({ create_default_organization }) {
    this.create_default_organization = create_default_organization;
  },
  metadata_fields: function ({ metadata_fields }) {
    this.metadata_fields = metadata_fields.map((field) => {
      field.scopes ||= [];
      field.scopes = field.scopes.map((name) => ({ name }));
      return field;
    });
  },
  federated_servers: function ({ federated_servers }) {
    this.federated_servers = federated_servers.map((federatedServer) => {
      return {
        ...federatedServer,
        isDiscovery: !!federatedServer.discovery_path,
      };
    });
  },
  verifiable_credentials: function ({ verifiable_credentials }) {
    this.verifiable_credentials = verifiable_credentials;
  },
  features: function ({ features }) {
    this.features = features;
  },
  password_hashing_alg: function ({ password_hashing_alg }) {
    this.password_hashing_alg = password_hashing_alg;
  },
  password_hashing_opts: function ({ password_hashing_opts }) {
    this.password_hashing_opts = password_hashing_opts;
  },
  ldap_pool_size: function ({ ldap_pool_size }) {
    this.ldap_pool_size = ldap_pool_size;
  },
  ldap_host: function ({ ldap_host }) {
    this.ldap_host = ldap_host;
  },
  ldap_user_rdn_attribute: function ({ ldap_user_rdn_attribute }) {
    this.ldap_user_rdn_attribute = ldap_user_rdn_attribute;
  },
  ldap_base_dn: function ({ ldap_base_dn }) {
    this.ldap_base_dn = ldap_base_dn;
  },
  ldap_ou: function ({ ldap_ou }) {
    this.ldap_ou = ldap_ou;
  },
  ldap_master_dn: function ({ ldap_master_dn }) {
    this.ldap_master_dn = ldap_master_dn;
  },
  ldap_master_password: function ({ ldap_master_password }) {
    this.ldap_master_password = ldap_master_password;
  },
  smtp_from: function ({ smtp_from }) {
    this.smtp_from = smtp_from;
  },
  smtp_relay: function ({ smtp_relay }) {
    this.smtp_relay = smtp_relay;
  },
  smtp_username: function ({ smtp_username }) {
    this.smtp_username = smtp_username;
  },
  smtp_password: function ({ smtp_password }) {
    this.smtp_password = smtp_password;
  },
  smtp_ssl: function ({ smtp_ssl }) {
    this.smtp_ssl = smtp_ssl;
  },
  smtp_tls: function ({ smtp_tls }) {
    this.smtp_tls = smtp_tls;
  },
  smtp_port: function ({ smtp_port }) {
    this.smtp_port = smtp_port;
  },
};

class Backend {
  constructor(params = {}) {
    Object.assign(this, defaults);

    Object.keys(params).forEach((key) => {
      this[key] = params[key];
      assign[key].bind(this)(params);
    });
  }

  get isPersisted() {
    return this.id && this.id != DEFAULT_ID;
  }

  save() {
    this.errors = null;
    // TODO trigger validate
    let response;
    const { id, serialized } = this;
    if (this.isPersisted) {
      response = this.constructor
        .api()
        .patch(`/${id}`, { backend: serialized });
    } else {
      response = this.constructor.api().post("/", { backend: serialized });
    }

    return response
      .then(({ data }) => {
        const params = data.data;

        Object.keys(params).forEach((key) => {
          this[key] = params[key];
          assign[key].bind(this)(params);
        });
        return this;
      })
      .catch((error) => {
        const { errors } = error.response.data;
        this.errors = errors;
        throw errors;
      });
  }

  destroy() {
    return this.constructor
      .api()
      .delete(`/${this.id}`)
      .catch((error) => {
        const { code, message, errors } = error.response.data;
        this.errors = errors;
        throw { code, message, errors };
      });
  }

  get serialized() {
    const {
      id,
      name,
      type,
      roles,
      is_default,
      create_default_organization,
      password_hashing_alg,
      password_hashing_opts,
      metadata_fields,
      federated_servers,
      verifiable_credentials,
      ldap_pool_size,
      ldap_host,
      ldap_user_rdn_attribute,
      ldap_base_dn,
      ldap_ou,
      ldap_master_dn,
      ldap_master_password,
      smtp_from,
      smtp_relay,
      smtp_username,
      smtp_password,
      smtp_ssl,
      smtp_tls,
      smtp_port,
    } = this;
    const formattedPasswordHashingOpts = {};
    Object.keys(password_hashing_opts).forEach((key) => {
      const value = password_hashing_opts[key];
      if (value !== "") {
        formattedPasswordHashingOpts[key] = value;
      }
    });

    return {
      id,
      name,
      roles: roles.map(({ model }) => model.serialized),
      type,
      is_default,
      create_default_organization,
      password_hashing_alg,
      password_hashing_opts: formattedPasswordHashingOpts,
      metadata_fields: metadata_fields.map(
        ({ attribute_name, user_editable, scopes }) => ({
          attribute_name,
          user_editable,
          scopes: scopes.map(({ name }) => name),
        })
      ),
      federated_servers: federated_servers.map((federatedServer) => {
        const federated_server = Object.assign({}, federatedServer)
        if (!federated_server.isDiscovery) {
          delete federated_server.discovery_path;
        }
        delete federated_server.isDiscovery;
        return federated_server;
      }),
      verifiable_credentials,
      ldap_pool_size,
      ldap_host,
      ldap_user_rdn_attribute,
      ldap_base_dn,
      ldap_ou,
      ldap_master_dn,
      ldap_master_password,
      smtp_from,
      smtp_relay,
      smtp_username,
      smtp_password,
      smtp_ssl,
      smtp_tls,
      smtp_port,
    };
  }

  resetPasswordAlgorithmOpts() {
    this.password_hashing_opts = {};
  }

  static get passwordHashingAlgorithms() {
    return [
      { name: "argon2", label: "Argon2" },
      { name: "bcrypt", label: "Bcrypt" },
      { name: "pbkdf2", label: "Pbkdf2" },
    ];
  }

  static get passwordHashingOpts() {
    return {
      argon2: [
        {
          name: "salt_len",
          type: "number",
          label: "Length of the random salt (in bytes)",
          default: 16,
        },
        { name: "t_cost", type: "number", label: "Time cost", default: 8 },
        { name: "m_cost", type: "number", label: "Memory usage", default: 16 },
        {
          name: "parallelism",
          type: "number",
          label: "Number of parralel threads",
          default: 2,
        },
        {
          name: "format",
          type: "text",
          label: "Output format (encoded, raw_hash, or report)",
          default: "encoded",
        },
        {
          name: "hashlen",
          type: "number",
          label: "Length of the hash (in bytes)",
          default: 32,
        },
        {
          name: "argon2_type",
          type: "number",
          label: "Argon2 type (0 argon2d, 1 argon2i, 2 argon2id)",
          default: 2,
        },
      ],
      bcrypt: [
        {
          name: "log_rounds",
          type: "number",
          label: "The computational cost as number of log rounds",
          default: 12,
        },
        {
          name: "legacy",
          type: "checkbox",
          label: 'Generate salts with the old "$2a$" prefix',
          default: false,
        },
      ],
      pbkdf2: [
        {
          name: "salt_len",
          type: "number",
          label: "The length of the random salt",
          default: 16,
        },
        {
          name: "format",
          type: "text",
          label: "The output format of the hash (modular, django, or hex)",
          default: "modular",
        },
        {
          name: "digest",
          type: "text",
          label: "The sha algorithm that pbkdf2 will use",
          default: "sha512",
        },
        {
          name: "length",
          type: "number",
          label: "The length of the hash (in bytes)",
          default: 64,
        },
      ],
    };
  }

  static api() {
    const accessToken = localStorage.getItem("access_token");

    const instance = axios.create({
      baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/backends`,
      headers: { Authorization: `Bearer ${accessToken}` },
    });

    return addClientErrorInterceptor(instance);
  }

  static all() {
    return this.api()
      .get("/")
      .then(({ data }) => {
        return data.data.map(
          (identityProvider) => new Backend(identityProvider)
        );
      });
  }

  static get(id) {
    return this.api()
      .get(`/${id}`)
      .then(({ data }) => {
        return new Backend(data.data);
      });
  }
}

export default Backend;
