<template>
  <div class="dashboard tokens-dashboard">
    <div class="container">
      <div class="ui error message" v-if="errorMessage">
        {{ errorMessage }}
      </div>

      <div class="ui dates form">
        <div class="ui stackable grid">
          <div class="four wide token-times column">
            <h1>Tokens</h1>
          </div>
          <div class="five wide token-times column">
            <input type="datetime-local" v-model="dateFilter.startAt" :disabled="pending" />
          </div>
          <div class="five wide token-times column">
            <input type="datetime-local" v-model="dateFilter.endAt" :disabled="pending" />
          </div>
          <div class="two wide token-times column">
            <button class="ui fluid blue button" @click="search()" :disabled="pending">Filter</button>
          </div>
        </div>
      </div>

      <div class="ui stackable equal height grid token-summary-row">
        <div class="thirteen wide column">
          <div class="ui segment token-search-panel">
            <form class="ui form" @submit.prevent="search()">
              <div class="three fields">
                <div class="field">
                  <label>Client</label>
                  <select v-model="clientId" @change="search()" :disabled="pending">
                    <option value="">All clients</option>
                    <option :value="client.id" v-for="client in clients" :key="client.id">
                      {{ client.name || client.id }}
                    </option>
                  </select>
                </div>
                <div class="field">
                  <label>Type</label>
                  <select v-model="type" @change="search()" :disabled="pending">
                    <option value="">All types</option>
                    <option :value="tokenType" v-for="tokenType in tokenTypes" :key="tokenType">
                      {{ tokenType }}
                    </option>
                  </select>
                </div>
                <div class="field">
                  <label>Scope</label>
                  <select v-model="scope" @change="search()" :disabled="pending">
                    <option value="">All scopes</option>
                    <option :value="tokenScope" v-for="tokenScope in tokenScopes" :key="tokenScope">
                      {{ tokenScope }}
                    </option>
                  </select>
                </div>
              </div>
              <div class="field">
                <div class="ui action input fluid">
                  <input
                    type="text"
                    v-model="tokenQuery"
                    placeholder="search"
                    :disabled="pending" />
                  <button class="ui blue button" type="submit" :disabled="pending">Search</button>
                </div>
              </div>
            </form>
          </div>
        </div>
        <div class="three wide column">
          <div class="ui segment token-types-chart">
            <PieChart
              v-if="totalEntries"
              class="token-types-pie"
              :chart-data="tokenTypeChartData"
              :options="tokenTypeChartOptions"
              height="190" />
          </div>
        </div>
      </div>

      <div class="ui segment token-issued-chart" v-if="hasIssuedTokenCounts">
        <LineChart
          :chartData="issuedTokenChartData"
          :options="issuedTokenChartOptions"
          :key="issuedTokenChartRerenders"
          height="220" />
      </div>

      <div class="ui stackable grid token-list-row">
        <div class="sixteen wide column">
          <div class="ui styled fluid accordion token-list-accordion" v-if="tokens.length">
            <div
              class="chain-accordion"
              :class="{ 'single-token': !isCodeChain(group) }"
              v-for="group in tokenGroups"
              :key="group.key">
              <div
                v-if="isCodeChain(group)"
                class="title chain-title"
                :class="{ active: isChainExpanded(group) }"
                @click="toggleChain(group)"
                @keyup.enter="toggleChain(group)"
                @keyup.space.prevent="toggleChain(group)"
                role="button"
                tabindex="0"
                :aria-expanded="isChainExpanded(group)">
                <div class="chain-title-main">
                  <i class="dropdown icon"></i>
                  <span class="ui tiny violet label" v-if="isCodeChain(group)">{{ lastToken(group).type }}</span>
                  <span class="ui tiny basic label" v-else>token</span>
                  <span class="chain-id monospace">{{ group.label }}</span>
                </div>
                <div class="chain-title-status">
                  <span class="ui tiny basic label">{{ group.tokens.length }} token(s)</span>
                  <span class="ui tiny red label" v-if="lastTokenStatus(group) === 'revoked'">revoked</span>
                  <span class="ui tiny green label" v-else-if="lastTokenStatus(group) === 'active'">active</span>
                  <span class="ui tiny grey label" v-else>expired</span>
                </div>
              </div>

              <div
                class="content chain-content"
                :class="{ active: isCodeChain(group) ? isChainExpanded(group) : true }">
                <div class="ui styled fluid accordion chain-token-list">
                  <div class="token-accordion" v-for="token in group.tokens" :key="group.key + token.id">
                    <div
                      class="title token-title"
                      :class="{ active: isTokenExpanded(token) }"
                      @click.stop="toggleToken(token)"
                      @keyup.enter.stop="toggleToken(token)"
                      @keyup.space.stop.prevent="toggleToken(token)"
                      role="button"
                      tabindex="0"
                      :aria-expanded="isTokenExpanded(token)">
                      <div class="token-title-main">
                        <i class="dropdown icon"></i>
                        <span class="ui tiny basic label">{{ token.type }}</span>
                        <span class="token-id monospace">{{ token.value }}</span>
                      </div>
                      <div class="token-title-status">
                        <span class="ui tiny red label" v-if="token.revoked_at">revoked</span>
                        <span class="ui tiny green label" v-else-if="isActive(token)">active</span>
                        <span class="ui tiny grey label" v-else>expired</span>
                      </div>
                    </div>

                    <div class="content" :class="{ active: isTokenExpanded(token) }">
                      <div class="ui segment">
                        <div class="token-actions" v-if="canRevoke(token)">
                          <button
                            class="ui tiny red button"
                            :class="{ loading: isRevoking(token) }"
                            :disabled="isRevoking(token)"
                            type="button"
                            @click="revokeToken(token)">
                            Revoke {{ token.type }}
                          </button>
                        </div>
                        <div class="ui two column stackable grid">
                          <div class="column">
                            <div class="ui attribute list">
                              <div class="item">
                                <span class="header">Identifier</span>
                                <span class="token-value description monospace" :title="token.value">{{ token.id }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Client</span>
                                <span class="description" v-if="token.client">{{ token.client.name || token.client.id }}</span>
                                <span class="description" v-else>{{ token.public_client_id || '-' }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Scope</span>
                                <span class="description" v-if="token.scope.length">
                                  <span class="ui tiny teal label" v-for="scope in token.scope" :key="scope">{{ scope }}</span>
                                </span>
                                <span class="description" v-else>-</span>
                              </div>
                              <div class="item">
                                <span class="header">Expires at</span>
                                <span class="description">{{ formatUnixDate(token.expires_at) }}</span>
                              </div>
                              <div class="item" v-if="token.previous_code">
                                <span class="header">Previous code</span>
                                <span class="token-value description monospace" :title="token.previous_code">{{ token.previous_code }}</span>
                              </div>
                            </div>
                          </div>
                          <div class="column">
                            <div class="ui attribute list">
                              <div class="item">
                                <span class="header">Subject</span>
                                <span class="description monospace">{{ token.sub || '-' }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Refresh token</span>
                                <span class="token-value description monospace" :title="token.refresh_token">{{ token.refresh_token || '-' }}</span>
                              </div>
                              <div class="item" v-if="token.previous_token">
                                <span class="header">Previous token</span>
                                <span class="token-value description monospace" :title="token.previous_token">{{ token.previous_token }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Inserted at</span>
                                <span class="description">{{ formatDate(token.inserted_at) }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Updated at</span>
                                <span class="description">{{ formatDate(token.updated_at) }}</span>
                              </div>
                            </div>
                          </div>
                        </div>

                        <div class="ui styled fluid accordion token-detail-accordion" v-if="token.user">
                          <div
                            class="title"
                            :class="{ active: isUserExpanded(token) }"
                            @click.stop="toggleUser(token)"
                            @keyup.enter.stop="toggleUser(token)"
                            @keyup.space.stop.prevent="toggleUser(token)"
                            role="button"
                            tabindex="0"
                            :aria-expanded="isUserExpanded(token)">
                            <i class="dropdown icon"></i>
                            user
                            <span class="token-detail-summary">{{ tokenUserLabel(token.user) }}</span>
                            <span class="token-detail-status">
                              <span class="ui tiny red label" v-if="token.user.blocked">blocked</span>
                              <span class="ui tiny green label" v-else>active</span>
                            </span>
                          </div>
                          <div class="content" :class="{ active: isUserExpanded(token) }">
                            <div class="ui attribute list">
                              <div class="item">
                                <span class="header">ID</span>
                                <span class="description monospace">{{ token.user.id }}</span>
                              </div>
                              <div class="item">
                                <span class="header">UID</span>
                                <span class="description">{{ token.user.uid || '-' }}</span>
                              </div>
                              <div class="item">
                                <span class="header">Username</span>
                                <span class="description">{{ token.user.username || '-' }}</span>
                              </div>
                            </div>
                          </div>
                        </div>

                        <div
                          class="ui styled fluid accordion token-detail-accordion"
                          v-for="presentationToken in tokenPresentationTokens(token)"
                          :key="presentationToken.name">
                          <div
                            class="title"
                            :class="{ active: isPresentationTokenExpanded(token, presentationToken) }"
                            @click.stop="togglePresentationToken(token, presentationToken)"
                            @keyup.enter.stop="togglePresentationToken(token, presentationToken)"
                            @keyup.space.stop.prevent="togglePresentationToken(token, presentationToken)"
                            role="button"
                            tabindex="0"
                            :aria-expanded="isPresentationTokenExpanded(token, presentationToken)">
                            <i class="dropdown icon"></i>
                            {{ presentationToken.label }}
                            <span class="token-detail-summary monospace" :title="presentationToken.value">
                              {{ presentationToken.value }}
                            </span>
                            <span class="token-detail-status">
                              <span class="ui tiny green label" v-if="presentationToken.result?.verified">verified</span>
                              <span class="ui tiny red label" v-else>not verified</span>
                            </span>
                          </div>
                          <div class="content" :class="{ active: isPresentationTokenExpanded(token, presentationToken) }">
                            <div class="ui segment">
                              <div class="ui attribute list token-claims-list" v-if="presentationToken.result?.claims">
                                <div class="item" v-for="claim in tokenClaimAttributes(presentationToken.result.claims)" :key="claim.name">
                                  <span class="header">{{ claim.name }}</span>
                                  <span class="description monospace">{{ claim.value }}</span>
                                </div>
                              </div>
                              <pre class="token-claims token-claims-error" v-else>{{ presentationToken.result?.error || 'No claims available.' }}</pre>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="ui center aligned segment">
        <div class="total-entries">{{ totalEntries }} record(s)</div>
        <div class="ui pagination menu">
          <button
            :disabled="disableFirstPage"
            class="item"
            @click="goToPage(1)">
            &lt;
          </button>
          <button
            class="item"
            :class="{ 'active': currentPage == pageNumber }"
            v-for="pageNumber in meanPages"
            :key="pageNumber"
            @click="goToPage(pageNumber)">
            {{ pageNumber }}
          </button>
          <button
            :disabled="disableLastPage"
            class="item"
            @click="goToPage(totalPages)">
            &gt;
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import moment from 'moment'
import { LineChart, PieChart } from "vue-chart-3"
import { Chart, registerables } from 'chart.js'
import 'chartjs-adapter-moment'
import Client from '../../models/client.model'
import Token from '../../models/token.model'

Chart.register(...registerables)

export default {
  name: 'tokens-dashboard',
  components: {
    LineChart,
    PieChart
  },
  data () {
    return {
      tokens: [],
      pending: false,
      errorMessage: false,
      clients: [],
      tokenScopes: [],
      tokenTypes: [],
      tokenTypeCounts: {},
      tokenCounts: {},
      tokenCountsTimeScaleUnit: 'hour',
      issuedTokenChartRerenders: 0,
      clientId: this.$route.query.client_id || '',
      type: this.$route.query.type || '',
      scope: this.$route.query.scope || '',
      dateFilter: {
        startAt: this.$route.query.startAt || moment().utc().subtract(1, 'month').format("yyyy-MM-DDTHH:mm"),
        endAt: this.$route.query.endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm")
      },
      currentPage: Number(this.$route.query.page || 1),
      tokenQuery: this.$route.query.q || '',
      totalPages: 1,
      totalEntries: 0,
      expandedChainIds: [],
      expandedTokenIds: [],
      expandedUserTokenIds: [],
      expandedPresentationTokenIds: [],
      revokingTokenIds: [],
      tokenTypeChartOptions: {
        animation: false,
        cutout: '30%',
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: false
          },
          legend: {
            display: false
          }
        }
      }
    }
  },
  mounted () {
    this.getClients()
  },
  computed: {
    meanPages () {
      const meanPages = []

      let firstPage = this.currentPage - 1
      if (firstPage < 1) firstPage = 1
      let lastPage = firstPage + 2
      if (lastPage > this.totalPages) {
        lastPage = this.totalPages
        firstPage = lastPage - 2 < 1 ? 1 : lastPage - 2
      }

      for (let i = firstPage; i <= lastPage; i++) { meanPages.push(i) }

      return meanPages
    },
    disableFirstPage () {
      return this.meanPages[0] == 1
    },
    disableLastPage () {
      return this.meanPages.slice(-1) == this.totalPages
    },
    tokenTypeChartData () {
      const labels = Object.keys(this.tokenTypeCounts).sort()

      return {
        labels,
        datasets: [
          {
            backgroundColor: labels.map((label) => this.tokenTypeColor(label)),
            data: labels.map((label) => this.tokenTypeCounts[label])
          }
        ]
      }
    },
    hasIssuedTokenCounts () {
      return Object.values(this.tokenCounts).some((counts) => Object.keys(counts).length)
    },
    issuedTokenChartData () {
      const labels = [...new Set(Object.values(this.tokenCounts).flatMap((counts) => Object.keys(counts)))].sort()

      return {
        labels,
        datasets: Object.keys(this.tokenCounts).sort().map((type) => {
          const counts = this.tokenCounts[type]

          return {
            label: type,
            borderColor: this.tokenTypeColor(type),
            backgroundColor: this.tokenTypeColor(type),
            fill: false,
            lineTension: 0,
            data: Object.keys(counts).sort().map((timestamp) => {
              return {
                x: timestamp,
                y: counts[timestamp]
              }
            })
          }
        })
      }
    },
    issuedTokenChartOptions () {
      return {
        animation: false,
        plugins: {
          title: {
            display: true,
            text: `Issued tokens per ${this.tokenCountsTimeScaleUnit}`
          },
          legend: {
            align: 'start',
            position: 'bottom'
          }
        },
        scales: {
          x: {
            type: 'timeseries',
            time: {
              unit: this.tokenCountsTimeScaleUnit,
              round: true
            }
          },
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0
            }
          }
        }
      }
    },
    tokenGroups () {
      const tokensWithPreviousCodes = this.tokens.map((token) => {
        const previousCodes = token.previous_codes || []

        return {
          key: token.value,
          tokens: previousCodes.concat(token)
        }
      })

      return tokensWithPreviousCodes.reduce((groups, tokenWithPreviousCodes) => {
        const key = tokenWithPreviousCodes.key
        let group = groups.find((group) => group.key === key)

        if (!group) {
          group = { key, label: key, tokens: [] }
          groups.push(group)
        }

        tokenWithPreviousCodes.tokens.forEach((chainToken) => {
          if (!group.tokens.some((groupToken) => groupToken.id === chainToken.id)) {
            group.tokens.push(chainToken)
          }
        })

        return groups
      }, [])
    }
  },
  methods: {
    getClients () {
      Client.all().then((clients) => {
        this.clients = clients
      }).catch()
    },
    getTokens (pageNumber, query, clientId, scope, type, startAt, endAt) {
      this.pending = true
      this.errorMessage = false

      Token.all({ query, pageNumber, clientId, scope, type, startAt, endAt }).then(({ data, scopes, types, typeCounts, tokenCounts, tokenCountsTimeScaleUnit, currentPage, totalPages, totalEntries }) => {
        this.tokens = data
        this.tokenScopes = scopes
        this.tokenTypes = types
        this.tokenTypeCounts = typeCounts || {}
        this.tokenCounts = tokenCounts || {}
        this.tokenCountsTimeScaleUnit = tokenCountsTimeScaleUnit || 'hour'
        this.issuedTokenChartRerenders += 1
        this.totalPages = totalPages
        this.totalEntries = totalEntries
        this.currentPage = currentPage
      }).catch((error) => {
        this.errorMessage = error.response?.data?.message || 'An error has occured when fetching tokens.'
      }).finally(() => {
        this.pending = false
      })
    },
    goToPage (pageNumber) {
      const query = { page: pageNumber }
      if (this.tokenQuery) query.q = this.tokenQuery
      if (this.clientId) query.client_id = this.clientId
      if (this.scope) query.scope = this.scope
      if (this.type) query.type = this.type
      query.startAt = this.dateFilter.startAt
      query.endAt = this.dateFilter.endAt

      this.$router.push({ name: 'token-list', query })
    },
    search () {
      const query = {}
      if (this.tokenQuery) query.q = this.tokenQuery
      if (this.clientId) query.client_id = this.clientId
      if (this.scope) query.scope = this.scope
      if (this.type) query.type = this.type
      query.startAt = this.dateFilter.startAt
      query.endAt = this.dateFilter.endAt

      this.$router.push({ name: 'token-list', query })
    },
    formatUnixDate (timestamp) {
      if (!timestamp) return '-'

      return moment.unix(timestamp).format('YYYY-MM-DD HH:mm:ss')
    },
    formatDate (date) {
      if (!date) return '-'

      return moment(date).format('YYYY-MM-DD HH:mm:ss')
    },
    isActive (token) {
      return token.expires_at && token.expires_at > moment().unix()
    },
    tokenTypeColor (type) {
      const colors = {
        access_token: '#2185d0',
        agent_token: '#00b5ad',
        refresh_token: '#21ba45',
        code: '#6435c9',
        preauthorized_code: '#f2711c'
      }

      return colors[type] || '#767676'
    },
    canRevoke (token) {
      return ['access_token', 'agent_token', 'code'].includes(token.type) &&
        !token.revoked_at &&
        this.isActive(token)
    },
    isRevoking (token) {
      return this.revokingTokenIds.includes(token.id)
    },
    revokeToken (token) {
      if (!window.confirm(`Revoke this ${token.type}?`)) return

      this.revokingTokenIds = [...this.revokingTokenIds, token.id]
      this.errorMessage = false

      Token.revoke(token).then((revokedToken) => {
        this.tokens = this.tokens.map((currentToken) => {
          return currentToken.id === revokedToken.id ? revokedToken : currentToken
        })
      }).catch((error) => {
        this.errorMessage = error.response?.data?.message || 'An error has occured when revoking token.'
      }).finally(() => {
        this.revokingTokenIds = this.revokingTokenIds.filter((tokenId) => tokenId !== token.id)
      })
    },
    isCodeChain (group) {
      return group.tokens.length > 1 || group.tokens.some((token) => token.previous_codes?.length)
    },
    lastToken (group) {
      return group.tokens[group.tokens.length - 1]
    },
    lastTokenStatus (group) {
      const token = this.lastToken(group)
      if (token.revoked_at) return 'revoked'
      if (this.isActive(token)) return 'active'
      return 'expired'
    },
    isChainExpanded (group) {
      return this.expandedChainIds.includes(group.key)
    },
    toggleChain (group) {
      if (this.isChainExpanded(group)) {
        this.expandedChainIds = this.expandedChainIds.filter((chainId) => chainId !== group.key)
      } else {
        this.expandedChainIds = [...this.expandedChainIds, group.key]
      }
    },
    isTokenExpanded (token) {
      return this.expandedTokenIds.includes(token.id)
    },
    toggleToken (token) {
      if (this.isTokenExpanded(token)) {
        this.expandedTokenIds = this.expandedTokenIds.filter((tokenId) => tokenId !== token.id)
      } else {
        this.expandedTokenIds = [...this.expandedTokenIds, token.id]
      }
    },
    isUserExpanded (token) {
      return this.expandedUserTokenIds.includes(token.id)
    },
    toggleUser (token) {
      if (this.isUserExpanded(token)) {
        this.expandedUserTokenIds = this.expandedUserTokenIds.filter((tokenId) => tokenId !== token.id)
      } else {
        this.expandedUserTokenIds = [...this.expandedUserTokenIds, token.id]
      }
    },
    tokenUserLabel (user) {
      return user.username || user.uid || user.id
    },
    presentationTokenKey (token, presentationToken) {
      return `${token.id}:${presentationToken.name}`
    },
    isPresentationTokenExpanded (token, presentationToken) {
      return this.expandedPresentationTokenIds.includes(this.presentationTokenKey(token, presentationToken))
    },
    togglePresentationToken (token, presentationToken) {
      const key = this.presentationTokenKey(token, presentationToken)

      if (this.isPresentationTokenExpanded(token, presentationToken)) {
        this.expandedPresentationTokenIds = this.expandedPresentationTokenIds.filter((tokenId) => tokenId !== key)
      } else {
        this.expandedPresentationTokenIds = [...this.expandedPresentationTokenIds, key]
      }
    },
    tokenPresentationTokens (token) {
      return [
        {
          name: 'id_token',
          label: 'id_token',
          value: token.id_token,
          result: token.id_token_claims
        }
      ].filter((presentationToken) => presentationToken.value)
    },
    tokenClaimAttributes (claims) {
      return Object.keys(claims).sort().map((name) => {
        return {
          name,
          value: this.formatClaimValue(claims[name])
        }
      })
    },
    formatClaimValue (value) {
      if (value === null || value === undefined) return '-'
      if (typeof value === 'object') return JSON.stringify(value, null, 2)

      return String(value)
    }
  },
  watch: {
    '$route.query': {
      handler ({ page, q, client_id, scope, type, startAt, endAt }) {
        this.tokenQuery = q || ''
        this.clientId = client_id || ''
        this.scope = scope || ''
        this.type = type || ''
        this.dateFilter = {
          startAt: startAt || moment().utc().subtract(1, 'month').format("yyyy-MM-DDTHH:mm"),
          endAt: endAt || moment().utc().endOf('hour').format("yyyy-MM-DDTHH:mm")
        }
        this.getTokens(page, q, client_id, scope, type, this.dateFilter.startAt, this.dateFilter.endAt)
      },
      deep: true,
      immediate: true
    }
  }
}
</script>

<style scoped lang="scss">
.tokens-dashboard {
  .dates.form {
    margin-bottom: 1em;

    button {
      font-size: 1.08rem !important;
    }
  }

  .token-list-accordion.ui.styled.accordion {
    width: 100%;
  }

  .token-summary-row {
    align-items: stretch;

    > .column {
      display: flex !important;
    }
  }

  .token-search-panel,
  .token-types-chart {
    margin: 0 !important;
    min-height: 13rem;
    width: 100%;
  }

  .token-types-chart {
    display: flex;
  }

  .token-types-chart > * {
    width: 100%;
  }

  .token-types-pie {
    height: 100%;
  }

  .token-types-empty {
    align-items: center;
    display: flex;
    justify-content: center;
    min-height: 9rem;
    width: 100%;
  }

  @media only screen and (max-width: 767px) {
    .token-summary-row > .column {
      display: block !important;
      width: 100% !important;
    }

    .token-search-panel,
    .token-types-chart {
      min-height: auto;
    }
  }

  .token-list-row {
    align-items: flex-start;
  }

  .chain-accordion {
    overflow: hidden;

    &:last-child {
      border-bottom: 0;
    }
  }

  .token-list-accordion.ui.styled.accordion .chain-accordion > .chain-content {
    margin: 0;
    padding: 0 !important;
    padding-left: 1em !important;
  }

  .token-list-accordion.ui.styled.accordion .chain-accordion.single-token,
  .token-list-accordion.ui.styled.accordion .chain-accordion.single-token > .chain-content {
    display: contents !important;
    margin: 0;
    padding: 0 !important;
  }

  .chain-accordion.single-token > .chain-content > .chain-token-list.ui.styled.accordion {
    border-radius: 0;
    box-shadow: none;
    display: contents !important;
  }

  .chain-token-list.ui.styled.accordion {
    margin: 0;
    box-shadow: none;
    width: 100%;
  }

  .chain-token-list.ui.styled.accordion .token-title {
    padding: .65em 1em;
  }

  .chain-token-list.ui.styled.accordion .token-accordion > .content {
    padding: 0 1em 1em !important;
  }

  .chain-token-list.ui.styled.accordion .token-accordion > .content > .grid {
    margin-top: 0;
  }

  .chain-token-list.ui.styled.accordion .token-detail-accordion {
    margin-top: 0;
  }

  .token-accordion {
    border-top: 1px solid rgba(34, 36, 38, .10);
    overflow: hidden;

    &:first-child {
      border-top: 0;
    }
  }

  .chain-accordion.single-token:not(:first-child) .token-accordion {
    border-top: 1px solid rgba(34, 36, 38, .15);
  }

  .token-actions {
    float: right;
    margin: 0 0 1rem 1rem;
    @media (max-width: 768px) {
      float: none;
      margin: 0;
      .button {
        width: 100%;
      }
    }
  }

  .chain-title,
  .token-title {
    align-items: center;
    display: flex;
    gap: 1rem;
    justify-content: space-between;
  }

  .chain-title-main,
  .token-title-main {
    align-items: center;
    display: flex;
    min-width: 0;
  }

  .chain-title-status,
  .token-title-status {
    flex-shrink: 0;
  }

  .chain-id,
  .token-id {
    color: rgba(0, 0, 0, .55);
    margin-left: .5rem;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .token-value {
    display: block;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .token-detail-accordion {
    margin-top: 1rem;

    &:not(:last-child) {
      margin-bottom: 1rem;
    }

    &.ui.styled.accordion {
      width: 100%;
    }

    .title {
      align-items: center;
      display: flex;
      gap: .25rem;
      min-width: 0;
    }

    .token-detail-status {
      flex: 0 0 auto;
      margin-left: auto;
    }

    .token-detail-summary {
      color: rgba(0, 0, 0, .55);
      flex: 0 1 auto;
      font-family: monospace;
      margin-left: .5rem;
      min-width: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }
  .token-claims {
    background: rgba(0, 0, 0, .035);
    border-radius: .28571429rem;
    color: rgba(0, 0, 0, .8);
    margin: .75rem 0 0;
    max-height: 20rem;
    overflow: auto;
    padding: .75rem;
    white-space: pre-wrap;
    word-break: break-word;
  }
  .token-claims-error {
    color: #9f3a38;
  }
  .token-claims-list {
    column-count: 2;
    column-gap: 2rem;
    margin-top: .75rem !important;

    .item {
      break-inside: avoid;
      page-break-inside: avoid;
    }

    .description {
      overflow-wrap: anywhere;
      white-space: pre-wrap;
    }
  }

  @media only screen and (max-width: 767px) {
    .token-claims-list {
      column-count: 1;
    }
  }
  .monospace {
    font-family: monospace;
  }
}
</style>
