import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  errors: null,
  client: null,
  previous_codes: []
}

const assign = {
  id: function ({ id }) { this.id = id },
  type: function ({ type }) { this.type = type },
  response_type: function ({ response_type }) { this.response_type = response_type },
  value: function ({ value }) { this.value = value },
  refresh_token: function ({ refresh_token }) { this.refresh_token = refresh_token },
  previous_code: function ({ previous_code }) { this.previous_code = previous_code },
  previous_codes: function ({ previous_codes }) {
    this.previous_codes = (previous_codes || [])
      .map((previousCode) => new Token(previousCode))
  },
  previous_token: function ({ previous_token }) { this.previous_token = previous_token },
  agent_token: function ({ agent_token }) { this.agent_token = agent_token },
  scope: function ({ scope }) { this.scope = scope },
  requested_scope: function ({ requested_scope }) { this.requested_scope = requested_scope },
  redirect_uri: function ({ redirect_uri }) { this.redirect_uri = redirect_uri },
  expires_at: function ({ expires_at }) { this.expires_at = expires_at },
  revoked_at: function ({ revoked_at }) { this.revoked_at = revoked_at },
  refresh_token_revoked_at: function ({ refresh_token_revoked_at }) { this.refresh_token_revoked_at = refresh_token_revoked_at },
  sub: function ({ sub }) { this.sub = sub },
  user: function ({ user }) { this.user = user },
  public_client_id: function ({ public_client_id }) { this.public_client_id = public_client_id },
  client: function ({ client }) { this.client = client },
  inserted_at: function ({ inserted_at }) { this.inserted_at = inserted_at },
  updated_at: function ({ updated_at }) { this.updated_at = updated_at }
}

class Token {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }
}

Token.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/tokens`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

Token.all = function ({ query, pageNumber, clientId, scope, type } = {}) {
  const searchParams = new URLSearchParams()
  pageNumber && searchParams.append('page', pageNumber)
  query && searchParams.append('q', query)
  clientId && searchParams.append('client_id', clientId)
  scope && searchParams.append('scope', scope)
  type && searchParams.append('type', type)

  return this.api().get(`/?${searchParams.toString()}`).then(({
    data: {
      data,
      scopes,
      types,
      type_counts: typeCounts,
      total_entries: totalEntries,
      page_number: currentPage,
      total_pages: totalPages
    }
  }) => {
    return {
      data: data.map((token) => new Token(token)),
      scopes,
      types,
      typeCounts,
      currentPage,
      totalPages,
      totalEntries
    }
  })
}

Token.revoke = function (token) {
  return this.api().post(`/${token.id}/revoke`).then(({ data: { data } }) => new Token(data))
}

export default Token
