<template>
  <div class="resource-activity">
    <div class="activity-heading">
      <h2>Activity <small>({{ activityTotal }} events)</small></h2>
      <div class="ui activity-range form">
        <div class="field">
          <label for="resource-activity-range">Period</label>
          <select
            id="resource-activity-range"
            v-model="activityRange"
            :disabled="pending"
            @change="getActivity()"
          >
            <option value="1">Last month</option>
            <option value="3">Last 3 months</option>
            <option value="6">Last 6 months</option>
            <option value="all">All</option>
          </select>
        </div>
      </div>
    </div>
    <div class="resource-events">
      <div class="ui active centered inline loader" v-if="pending"></div>
      <div class="ui error message" v-else-if="error">
        {{ error }}
      </div>
      <div class="ui info message" v-else-if="!activity.length">
        No activity recorded during the selected period.
      </div>
      <div class="ui event segment" v-for="event in activity" :key="activityEventKey(event)">
        <div
          class="ui timestamp message"
          :class="{ 'success': event.status === 'success', 'error': event.status === 'failure' }"
        >
          {{ formatDate(event.time) }}
          <header>{{ event.label }} - {{ event.status }}</header>
        </div>
        <div class="ui four column stackable grid attribute list">
          <div class="column item" v-for="([name, value]) in activityAttributes(event)" :key="name">
            <span class="header">{{ formatAttribute(name) }}</span>
            <span class="description">{{ value }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import BusinessLogStats from '../models/business-log-stats.model.js'
import moment from 'moment'

const MAX_ACTIVITY_EVENTS = 100

export default {
  name: 'resource-activity',
  props: {
    resourceId: {
      type: String,
      required: true
    }
  },
  data () {
    return {
      activity: [],
      activityTotal: 0,
      activityRange: '1',
      pending: false,
      error: null
    }
  },
  mounted () {
    this.getActivity()
  },
  methods: {
    getActivity () {
      this.pending = true
      this.error = null

      BusinessLogStats.all({
        startAt: this.activityRange === 'all'
          ? 'all'
          : moment().utc().subtract(Number(this.activityRange), 'months'),
        endAt: moment().utc(),
        application: 'boruta_admin',
        resourceId: this.resourceId,
        eventsOnly: true
      }).then(({ events }) => {
        const activity = events.sort(
          (firstEvent, secondEvent) => new Date(secondEvent.time) - new Date(firstEvent.time)
        )

        this.activityTotal = activity.length
        this.activity = activity.slice(0, MAX_ACTIVITY_EVENTS)
      }).catch((error) => {
        this.error = error.message || 'Could not load resource activity.'
      }).finally(() => {
        this.pending = false
      })
    },
    activityEventKey (event) {
      return `${event.application}-${event.request_id}-${event.label}-${event.time}`
    },
    activityAttributes (event) {
      return Object.entries(event.attributes || {}).sort(([firstName], [secondName]) => {
        return firstName.localeCompare(secondName)
      })
    },
    formatAttribute (name) {
      return name.replaceAll('_', ' ')
    },
    formatDate (date) {
      return new Date(date).toLocaleString(undefined, {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
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
  margin-bottom: 1em;

  h2 {
    margin: 0;
  }
}

.resource-events {
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
    padding-top: 2.5em!important;

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

    .attribute.list .column {
      padding-top: 0!important;
      padding-bottom: 0!important;
    }
  }
}

@media (max-width: 768px) {
  .activity-heading {
    flex-direction: column;
    width: 100%;

    .activity-range {
      margin-left: auto;
    }
  }
}
</style>
