<template>
  <div class="edit-user">
    <Toaster :active="success" message="User has been updated" type="success" />
    <div class="container">
      <div class="ui error message" v-if="error">
        {{ error }}
      </div>
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Backend</span>
                  <span class="description">{{ user.backend.name }}</span>
                </div>
                <div class="item">
                  <span class="header">User ID</span>
                  <span class="description">{{ user.id }}</span>
                </div>
                <div class="item">
                  <span class="header">User UID</span>
                  <span class="description">{{ user.uid }}</span>
                </div>
                <div class="item">
                  <span class="header">Username</span>
                  <span class="description">{{ user.username }}</span>
                </div>
                <div class="item">
                  <span class="header">Last login at</span>
                  <span class="description">{{ formatDate(user.last_login_at) }}</span>
                </div>
              </div>
            </div>
            <div class="ui segment" v-for="(attributes, federatedServerName) in user.federated_metadata">
              <h2>Federated attributes - {{ federatedServerName }}</h2>
              <div class="ui attribute list">
                <div class="item" v-for="(value, name) in attributes">
                  <span class="header">{{ name }}</span>
                  <span class="description">{{ value }}</span>
                </div>
              </div>
            </div>
            <router-link :to="{ name: 'user-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <UserForm :user="user" @submit="updateUser()" @back="back()" action="Update">
            <div class="ui user-activity segment">
              <div class="activity-heading">
                <h2>User activity <small>({{ activity.length }} events)</small></h2>
                <div class="ui activity-range form">
                  <div class="field">
                    <label for="activity-range">Period</label>
                    <select
                      id="activity-range"
                      v-model="activityRange"
                      :disabled="activityPending"
                      @change="getUserActivity()"
                    >
                      <option value="1">Last month</option>
                      <option value="3">Last 3 months</option>
                      <option value="6">Last 6 months</option>
                      <option value="all">All</option>
                    </select>
                  </div>
                </div>
              </div>
              <div class="user-events">
                <div class="ui active centered inline loader" v-if="activityPending"></div>
                <div class="ui error message" v-else-if="activityError">
                  {{ activityError }}
                </div>
                <div class="ui info message" v-else-if="!activity.length">
                  No activity recorded during the selected period.
                </div>
                <template v-for="event in activity" :key="activityEventKey(event)">
                  <div class="ui event segment">
                    <div
                      class="ui timestamp message"
                      :class="{ 'success': event.status == 'success', 'error': event.status == 'failure' }"
                      >
                      {{ formatDate(event.time) }}
                      <header>{{ event.label }} - {{ event.status }}</header>
                    </div>
                    <div class="ui four column stackable grid attribute list">
                      <div class="column item" v-for="(value, key) in event.attributes">
                        <span class="header">{{ key }}</span>
                        <span class="description">{{ value }}</span>
                      </div>
                    </div>
                  </div>
                </template>
              </div>
            </div>
          </UserForm>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import User from '../../models/user.model'
import UserForm from '../../components/Forms/UserForm.vue'
import Toaster from '../../components/Toaster.vue'
import BusinessLogStats from '../../models/business-log-stats.model.js'
import moment from 'moment'

const MAX_ACTIVITY_EVENTS = 100

export default {
  name: 'edit-user',
  components: {
    UserForm,
    Toaster
  },
  mounted() {
    const { userId } = this.$route.params
    User.get(userId).then((user) => {
      this.user = user
      this.getUserActivity()
    }).catch((error) => {
      this.error = error.response?.data?.message || error.message
    })
  },
  data() {
    return {
      user: new User(),
      success: false,
      error: null,
      activity: [],
      activityTotal: 0,
      activityRange: '1',
      activityPending: false,
      activityError: null,
      expandedActivity: {}
    }
  },
  methods: {
    getUserActivity() {
      this.activityPending = true
      this.activityError = null

      const activityQuery = {
        startAt: this.activityRange === 'all'
          ? 'all'
          : moment().utc().subtract(Number(this.activityRange), 'months'),
        endAt: moment().utc(),
        sub: this.user.id,
        eventsOnly: true
      }

      Promise.all([
        BusinessLogStats.all({ ...activityQuery, application: 'boruta_identity' }),
        BusinessLogStats.all({ ...activityQuery, application: 'boruta_web' }),
        BusinessLogStats.all({ ...activityQuery, application: 'boruta_admin' })
      ]).then((stats) => {
        const activity = stats
          .flatMap(({ events }) => events)
          .sort((firstEvent, secondEvent) => new Date(secondEvent.time) - new Date(firstEvent.time))

        this.activityTotal = activity.length
        this.activity = activity.slice(0, MAX_ACTIVITY_EVENTS)
      }).catch((error) => {
        this.activityError = error.message || 'Could not load user activity.'
      }).finally(() => {
        this.activityPending = false
      })
    },
    activityStatusClass(status) {
      return status === 'success' ? 'positive' : 'negative'
    },
    activityEventKey(event) {
      return `${event.application}-${event.request_id}-${event.label}-${event.time}`
    },
    activityAttributes(event) {
      return Object.entries(event.attributes || {}).sort(([firstName], [secondName]) => {
        return firstName.localeCompare(secondName)
      })
    },
    formatActivityAttribute(name) {
      return name.replaceAll('_', ' ')
    },
    isActivityExpanded(event) {
      return Boolean(this.expandedActivity[this.activityEventKey(event)])
    },
    toggleActivityDetails(event) {
      const key = this.activityEventKey(event)
      this.expandedActivity[key] = !this.expandedActivity[key]
    },
    formatDate(date) {
      if (!date) return 'Never'

      return new Date(date).toLocaleString(undefined, {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
    },
    back() {
      this.$router.push({ name: 'user-list' })
    },
    async updateUser () {
      this.success = false
      return this.user.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.activity-heading {
  align-items: flex-start;
  display: flex;
  gap: 1em;
  justify-content: space-between;

  h2 {
    margin: 0;
  }
  @media (max-width: 768px) {
    flex-direction: column;
    width: 100%;
    .activity-range {
      margin-left: auto;
    }
  }
}


.user-events {
  position: relative;
  max-height: 500px;
  overflow-y: scroll;
  .loader {
    position: absolute;
    width: 100%;
  }
  .event.segment {
    position: relative;
    margin-top: 2.5em!important;
    margin-left: 2em!important;
    padding-top: 1.5em!important;
    .timestamp {
      padding: .5em;
      position: absolute;
      display: inline-block;
      top: -2em;
      left: -1em;
      header {
        font-size: 1.2em;
        font-weight: bold;
      }
    }
    @media (max-width: 768px) {
      margin-top: 3.5em!important;
      .timestamp {
        top: -3em;
      }
    }
    .column {
      padding-bottom: 0!important;
    }
  }
}
</style>
