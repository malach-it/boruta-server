import axios from 'axios'
import { addClientErrorInterceptor } from './utils'

const defaults = {
  key_pair_type: { type: 'rsa', modulus_size: '1024', exponent_size: '65537' },
  type: 'Elixir.BorutaFederation.FederationEntities.LeafEntity',
  trust_chain_statement_alg: 'RS256',
  trust_chain_statement_ttl: 3600 * 24,
  authorities: []
}

const keyPairTypes = {
  'ec': { curve: ['P-256', 'P-384', 'P-512'] },
  'rsa': { modulus_size: '1024', exponent_size: '65537' }
}

const types = [
  'Elixir.BorutaFederation.FederationEntities.LeafEntity'
]

const statementSignatureAlgorithms = [
  'RS256',
  'RS384',
  'RS512',
  'ES256',
  'ES384',
  'ES512'
]

const assign = {
  id: function ({ id }) { this.id = id },
  organization_name: function ({ organization_name }) { this.organization_name = organization_name },
  type: function ({ type }) { this.type = type },
  authorities: function ({ authorities }) { this.authorities = authorities },
  is_default: function ({ is_default }) { this.is_default = is_default },
  trust_chain_statement_alg: function ({ trust_chain_statement_alg }) { this.trust_chain_statement_alg = trust_chain_statement_alg },
  trust_chain_statement_ttl: function ({ trust_chain_statement_ttl }) { this.trust_chain_statement_ttl = trust_chain_statement_ttl },
  trust_mark_logo_uri: function ({ trust_mark_logo_uri }) { this.trust_mark_logo_uri = trust_mark_logo_uri },
  key_pair_type: function ({ key_pair_type }) { this.key_pair_type = key_pair_type },
  public_key: function ({ public_key }) { this.public_key = public_key }
}

class FederationEntity {
  constructor (params = {}) {
    Object.assign(this, defaults)

    Object.keys(params).forEach((key) => {
      this[key] = params[key]
      assign[key].bind(this)(params)
    })
  }

  get persisted () {
    return !!this.id
  }

  save () {
    const { id, serialized } = this
    let response

    this.errors = null

    if (id) {
      response = this.constructor.api().patch(`/${id}`, { federation_entity: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    } else {
      response = this.constructor.api().post('/', { federation_entity: serialized })
        .then(({ data }) => Object.assign(this, data.data))
    }
    return response.catch((error) => {
      const { code, message, errors } = error.response.data
      this.errors = errors
      throw { code, message, errors }
    })
  }

  destroy () {
    return this.constructor.api().delete(`/${this.id}`)
      .catch((error) => {
        const { code, message, errors } = error.response.data
        this.errors = errors
        throw { code, message, errors }
      })
  }

  get serialized () {
    const {
      id,
      organization_name,
      authorities,
      type,
      trust_chain_statement_alg,
      trust_chain_statement_ttl,
      trust_mark_logo_uri,
      key_pair_type
    } = this

    return {
      id,
      organization_name,
      authorities: authorities,
      type,
      trust_chain_statement_alg,
      trust_chain_statement_ttl,
      trust_mark_logo_uri,
      key_pair_type
    }
  }
}

FederationEntity.keyPairTypes = keyPairTypes

FederationEntity.types = types

FederationEntity.statementSignatureAlgorithms = statementSignatureAlgorithms

FederationEntity.api = function () {
  const accessToken = localStorage.getItem('access_token')

  const instance = axios.create({
    baseURL: `${window.env.BORUTA_ADMIN_BASE_URL}/api/federation_entities`,
    headers: { 'Authorization': `Bearer ${accessToken}` }
  })

  return addClientErrorInterceptor(instance)
}

FederationEntity.all = function () {
  return this.api().get('/').then(({ data }) => {
    return data.data.map((federation_entity) => new FederationEntity(federation_entity))
  })
}

FederationEntity.get = function (id) {
  return this.api().get(`/${id}`).then(({ data }) => {
    return new FederationEntity(data.data)
  })
}

export default FederationEntity
