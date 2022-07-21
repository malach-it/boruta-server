class Logs {
  static stream() {
    const accessToken = localStorage.getItem('access_token')
    const stream = new ReadableStream({
      pull(controller) {
        controller.enqueue(chunk)
      }
    })

    return fetch(`${window.env.BORUTA_ADMIN_BASE_URL}/api/logs`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${accessToken}` },
    }).then(({ body }) => body.getReader())
  }
}

export default Logs
