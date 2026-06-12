<template>
  <div class="service-registry">
    <Toaster :active="deleted" message="Upstream has been deleted" type="warning" />
    <div class="container">
      <div class="ui error message" v-if="error">
        {{ error }}
      </div>
      <h2>Service registry</h2>
      <div class="ui fluid icon input search">
        <input type="search" v-model="searchQuery" placeholder="Search service registry" />
        <i class="search icon"></i>
      </div>
      <table class="ui celled compact table" v-if="filteredRecords.length">
        <thead>
          <tr>
            <th></th>
            <th>Node</th>
            <th>IP address</th>
            <th>Aliases</th>
            <th colspan="2">Status</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="record in filteredRecords" :key="record.id">
            <tr>
              <td class="collapsing">
                <button class="ui mini fold icon button" v-on:click="toggleRecord(record)">
                  <i class="angle icon" :class="isExpanded(record) ? 'down' : 'right'"></i>
                </button>
              </td>
              <td>{{ record.node_name }}</td>
              <td>{{ record.ip_address }}</td>
              <td>
                <span v-if="!record.aliases.length">-</span>
                <span v-for="alias in record.aliases" class="ui teal label" :key="alias">
                  {{ alias }}
                </span>
              </td>
              <td>
                <span class="ui label" :class="statusClass(record.status)">
                  {{ record.status }}
                </span>
              </td>
              <td class="collapsing">
                <router-link
                  v-if="canCreateUpstream(record)"
                  :to="newUpstreamRoute(record)"
                  class="ui mini violet button">Create upstream</router-link>
              </td>
            </tr>
            <tr v-if="isExpanded(record)" class="upstreams-row">
              <td colspan="6">
                <div class="ui mini segment" v-if="record.node_name !=='global'">
                  <span class="updated-at">Last update: {{ formatDate(record.updated_at) }}</span>
                </div>
                <div class="ui static-configuration segment" v-if="record.node_name !== 'global'">
                  <div class="ui six column stackable service-configurations grid">
                    <div
                      v-for="service in recordServices(record)"
                      class="service-configuration column"
                      :key="service.name">
                      <div class="ui service message card" :class="{ 'success': service.enabled, 'warning': !service.enabled }">
                        <div class="content">
                          <div class="header">
                            {{ service.name }}
                          </div>
                          <div class="ui mini description list">
                            <div class="item">
                              <strong>Scheme</strong>: {{ service.scheme.toUpperCase() }}
                            </div>
                            <div class="item">
                              <strong>Port</strong>: {{ service.port }}
                            </div>
                            <div class="item">
                              <strong>Acceptors</strong>: {{ service.acceptors }}
                            </div>
                            <div class="item" v-if="service.verify_client_certificate">
                              <strong>Force mTLS</strong>: true
                            </div>
                          </div>
                        </div>
                        <div class="extra-content">
                          <label v-if="service.enabled" class="ui green fluid label">Active</label>
                          <label v-if="!service.enabled" class="ui brown fluid label">Disabled</label>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div class="ui mini list certificate-paths">
                    <div class="item" v-for="path in certificatePaths(record)" :key="path.label">
                      <strong>{{ path.label }}</strong>: {{ path.value }}
                    </div>
                  </div>
                  <details v-if="record.certificate" class="certificate-details node-certificate">
                    <summary>Node certificate</summary>
                    <pre class="certificate">{{ record.certificate }}</pre>
                  </details>
                </div>
                <table class="ui very basic compact upstream table" v-if="upstreamsFor(record).length">
                  <thead>
                    <tr>
                      <th>Host</th>
                      <th>Base URL</th>
                      <th>Paths</th>
                      <th>Authorization</th>
                      <th>mTLS</th>
                      <th colspan="3">Rate limit</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="upstream in upstreamsFor(record)" :key="upstream.id">
                      <td>{{ upstream.virtual_host || '-' }}</td>
                      <td>{{ upstream.baseUrl }}</td>
                      <td>
                        <span v-for="path in upstream.uris" class="ui teal label" :key="path.uri">
                          {{ path.uri }}
                        </span>
                      </td>
                      <td>Authorization {{ upstream.authorize ? 'enabled' : 'disabled' }}</td>
                      <td>mTLS {{ upstream.mtls_enabled ? 'enabled' : 'disabled' }}</td>
                      <td>Rate limiting {{ upstream.rate_limit_enabled ? 'enabled' : 'disabled' }}</td>
                      <td class="collapsing">
                        <router-link
                          :to="{ name: 'edit-upstream', params: { upstreamId: upstream.id } }"
                          class="ui tiny blue button">edit</router-link>
                      </td>
                      <td class="collapsing">
                        <button
                          type="button"
                          class="ui tiny red button"
                          v-on:click="deleteUpstream(upstream)">
                          delete
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
                <div class="ui small message" v-else>
                  No upstreams configured for this node.
                </div>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
      <div class="ui placeholder segment" v-else-if="!error">
        <div class="ui icon header">
          <i class="server icon"></i>
          {{ records.length ? 'No matching services' : 'No registered services' }}
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import MiniSearch from 'minisearch'
import Toaster from '../../components/Toaster.vue'
import ServiceRegistryRecord from '../../models/service-registry-record.model'
import Upstream from '../../models/upstream.model'

export default {
  name: 'service-registry',
  components: {
    Toaster
  },
  data () {
    return {
      records: [],
      upstreams: {},
      expandedRecords: {},
      searchQuery: '',
      error: null,
      deleted: false,
      pollingInterval: null
    }
  },
  computed: {
    recordsWithGlobal () {
      return [
        {
          id: 'global',
          node_name: 'global',
          ip_address: 'all',
          aliases: [],
          status: 'global',
          certificate: null,
          configuration: this.globalConfiguration(),
          inserted_at: null,
          updated_at: null
        },
        ...this.records
      ]
    },
    filteredRecords () {
      const query = this.searchQuery.trim()

      if (!query) return this.recordsWithGlobal

      const recordsById = this.recordsWithGlobal.reduce((recordsById, record) => {
        recordsById[record.id] = record
        return recordsById
      }, {})

      const miniSearch = new MiniSearch({
        fields: ['node_name', 'ip_address', 'aliases', 'status', 'certificate', 'upstreams'],
        storeFields: ['id'],
        searchOptions: {
          prefix: true,
          fuzzy: 0.2
        }
      })

      miniSearch.addAll(this.recordsWithGlobal.map((record) => ({
        id: record.id,
        node_name: record.node_name || '',
        ip_address: record.ip_address || '',
        aliases: (record.aliases || []).join(' '),
        status: record.status || '',
        certificate: record.certificate || '',
        upstreams: this.upstreamsFor(record).map(this.upstreamSearchText).join(' ')
      })))

      return miniSearch.search(query).map(({ id }) => recordsById[id])
    }
  },
  mounted () {
    this.getData()
    this.pollingInterval = setInterval(this.getData, 10000)
  },
  beforeUnmount () {
    clearInterval(this.pollingInterval)
  },
  methods: {
    getData () {
      Promise.all([ServiceRegistryRecord.all(), Upstream.all()]).then(([records, upstreams]) => {
        this.records = records
        this.upstreams = upstreams
        this.error = null
      }).catch((error) => {
        this.error = error.response?.data?.message || error.message
      })
    },
    formatDate (date) {
      if (!date) return ''

      return new Date(date).toLocaleString(undefined, {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
    },
    statusClass (status) {
      if (status === 'global') return 'blue'

      return status === 'online' ? 'green' : 'grey'
    },
    toggleRecord (record) {
      this.expandedRecords = {
        ...this.expandedRecords,
        [record.id]: !this.expandedRecords[record.id]
      }
    },
    isExpanded (record) {
      return !!this.expandedRecords[record.id]
    },
    upstreamsFor (record) {
      return this.upstreams[record.node_name] || []
    },
    deleteUpstream (upstream) {
      if (!confirm('Are you sure you want to delete this upstream?')) return

      this.deleted = false
      this.error = null

      upstream.destroy().then(() => {
        this.deleted = true
        this.getData()
      }).catch((error) => {
        this.error = error.message || 'Could not delete upstream'
      })
    },
    globalConfiguration () {
      const configuredRecord = this.records.find(({ configuration }) => configuration)

      return configuredRecord?.configuration || { services: [], certificate_paths: {} }
    },
    recordServices (record) {
      return record.configuration?.services || []
    },
    certificatePaths (record) {
      const paths = record.configuration?.certificate_paths || {}

      return [
        { label: 'Certificate', value: paths.certificate },
        { label: 'Root CA certificate', value: paths.root_ca_certificate },
        { label: 'Trusted certificates', value: paths.trusted_certificates }
      ].filter(({ value }) => value)
    },
    canCreateUpstream (record) {
      return record.status !== 'root'
    },
    newUpstreamRoute (record) {
      return {
        name: 'new-upstream',
        query: {
          node_name: record.node_name
        }
      }
    },
    upstreamSearchText (upstream) {
      return [
        upstream.id,
        upstream.node_name,
        upstream.virtual_host,
        upstream.scheme,
        upstream.host,
        upstream.port,
        upstream.baseUrl,
        upstream.authorize ? 'authorization enabled' : 'authorization disabled',
        upstream.mtls_enabled ? 'mtls enabled' : 'mtls disabled',
        upstream.rate_limit_enabled ? 'rate limit enabled' : 'rate limit disabled',
        upstream.strip_uri ? 'strip uri enabled' : 'strip uri disabled',
        ...(upstream.uris || []).map(({ uri }) => uri),
        ...Object.entries(upstream.required_scopes || {}).flatMap(([method, scopes]) => {
          return [method, ...(scopes || [])]
        })
      ].filter((value) => value !== null && value !== undefined).join(' ')
    }
  }
}
</script>

<style scoped lang="scss">
.service-registry {
  .search {
    margin-bottom: 1rem;
  }

  .label {
    margin: .125rem;
  }

  .certificate-details {
    margin-top: .5rem;

    summary {
      cursor: pointer;
      font-weight: 700;
      line-height: 1.5;
      outline: none !important;
    }
  }

  .node-certificate {
    margin-top: .75rem;
  }

  .certificate {
    display: inline-block;
    margin: 1rem 0 0;
    padding: 1rem;
    max-height: 15rem;
    overflow: hidden;
    overflow-y: scroll !important;
    max-width: 100%;
    white-space: pre-wrap;
    word-break: break-all;
  }

  .service.card {
    height: 14.2em;
  }

  .ui.card>.content>.header, .ui.card>.content>.description {
    color: inherit;
  }

  @media (max-width: 768px) {
    .button {
      width: 100%;
    }
    .fold.button {
      text-align: left;
    }
    .service.card {
      margin: auto;
    }
  }
}
</style>
