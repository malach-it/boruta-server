import moment from 'moment'

class Logs {
  static stream({ startAt, endAt }) {
    const accessToken = localStorage.getItem('access_token')
    const stream = new ReadableStream({
      pull(controller) {
        controller.enqueue(chunk)
      }
    })

    const params = new URLSearchParams()
    params.append('start_at', moment.utc(startAt).toISOString())
    params.append('end_at', moment.utc(endAt).toISOString())

    return fetch(`${window.env.BORUTA_ADMIN_BASE_URL}/api/logs?${params.toString()}`, {
      method: 'GET',
      headers: { 'Authorization': `Bearer ${accessToken}` },
    }).then(({ body }) => body.getReader())
  }
}

export default Logs
