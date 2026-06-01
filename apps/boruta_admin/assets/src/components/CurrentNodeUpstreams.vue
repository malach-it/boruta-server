<template>
  <div class="ui current-node-upstreams segment">
    <h4 class="ui header">Current node upstreams</h4>
    <div class="ui small grey label">{{ currentNodeName }}</div>
    <div class="ui small error message" v-if="error">
      {{ error }}
    </div>
    <div class="ui relaxed divided list" v-else-if="currentNodeUpstreams.length">
      <div class="item" v-for="currentUpstream in currentNodeUpstreams" :key="currentUpstream.id">
        <div class="content">
          <router-link
            :to="{ name: 'edit-upstream', params: { upstreamId: currentUpstream.id } }"
            class="header">{{ currentUpstream.baseUrl }}</router-link>
          <div class="description">
            <span v-for="path in currentUpstream.uris" class="ui teal label" :key="path.uri">
              {{ path.uri }}
            </span>
          </div>
        </div>
      </div>
    </div>
    <div class="ui small message" v-else>
      No upstreams configured for this node.
    </div>
  </div>
</template>

<script>
import Upstream from '../models/upstream.model'

export default {
  name: 'current-node-upstreams',
  props: ['nodeName'],
  data () {
    return {
      upstreams: {},
      error: null
    }
  },
  mounted () {
    this.getUpstreams()
  },
  computed: {
    currentNodeName () {
      return this.nodeName || 'global'
    },
    currentNodeUpstreams () {
      return this.upstreams[this.currentNodeName] || []
    }
  },
  methods: {
    getUpstreams () {
      Upstream.all().then((upstreams) => {
        this.upstreams = upstreams
        this.error = null
      }).catch((error) => {
        this.error = error.response?.data?.message || error.message
      })
    }
  }
}
</script>

<style scoped lang="scss">
.current-node-upstreams {
  clear: both;
  margin-top: 1rem;

  .label {
    margin: .125rem;
  }

  .message {
    margin-bottom: 0;
  }
}
</style>
