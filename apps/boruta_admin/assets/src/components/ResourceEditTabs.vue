<template>
  <div class="resource-edit-tabs">
    <div class="ui top attached tabular menu">
      <a
        class="item"
        :class="{ active: activeTab === 'configuration' }"
        @click.prevent="activeTab = 'configuration'"
      >Configuration</a>
      <a
        class="item"
        :class="{ active: activeTab === 'activity' }"
        @click.prevent="activeTab = 'activity'"
      >Activity</a>
    </div>
    <div class="ui bottom attached active tab segment">
      <slot v-if="activeTab === 'configuration'" />
      <ResourceActivity v-else-if="resourceId" :resource-id="resourceId" />
      <div class="ui active centered inline loader" v-else></div>
    </div>
  </div>
</template>

<script>
import ResourceActivity from './ResourceActivity.vue'

export default {
  name: 'resource-edit-tabs',
  components: {
    ResourceActivity
  },
  props: {
    resourceId: {
      type: String,
      default: null
    }
  },
  data () {
    return {
      activeTab: 'configuration'
    }
  }
}
</script>
