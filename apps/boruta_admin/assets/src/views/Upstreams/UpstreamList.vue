<template>
  <div class="upstream-list">
    <Toaster :active="deleted" message="Upstream has been deleted" type="warning" />
    <router-link :to="{ name: 'new-upstream' }" class="ui violet main create button">Add an upstream</router-link>
    <div class="container">
      <div class="ui info message">
        Upstreams are here the configuration of the flow the gateway will apply for requests to be forwarded to backends. Corresponding to given paths, the gateway will route the request to the configured server.
      </div>
      <div class="ui segment" v-for="nodeName in Object.keys(upstreams)" :key="nodeName">
        <h2>{{ nodeName }}</h2>
        <div class="ui three column upstreams stackable grid">
          <div v-for="upstream in upstreams[nodeName]" :key="upstream.id" class="column">
            <div class="ui upstream highlightable segment">
              <div class="actions">
                <router-link
                  :to="{ name: 'edit-upstream', params: { upstreamId: upstream.id } }"
                  class="ui tiny blue button">edit</router-link>
                <a v-on:click="deleteUpstream(upstream)" class="ui tiny red button">delete</a>
              </div>
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Upstream ID</span>
                  <span class="description">{{ upstream.id }}</span>
                </div>
                <div class="item">
                  <span class="header">Base URL</span>
                  <span class="description">{{ upstream.baseUrl }}</span>
                </div>
                <div class="item">
                  <span class="header">Paths</span>
                  <div class="description">
                    <span v-for="path in upstream.uris" class="ui teal label" :key="path.uri">
                      {{ path.uri }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Upstream from '../../models/upstream.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'upstream-list',
  components: {
    Toaster
  },
  data () {
    return {
      upstreams: [],
      deleted: false
    }
  },
  mounted () {
    this.getUpstreams()
  },
  methods: {
    getUpstreams () {
      Upstream.all().then((upstreams) => {
        this.upstreams = upstreams
      })
    },
    deleteUpstream (upstream) {
      if (!confirm('Are you sure ?')) return
      this.deleted = false
      upstream.destroy().then(() => {
        this.deleted = true
        this.upstreams[upstream.node_name].splice(this.upstreams[upstream.node_name].indexOf(upstream), 1)
        if (!this.upstreams[upstream.node_name].length)
          delete this.upstreams[upstream.node_name]
      })
    }
  }
}
</script>

<style scoped lang="scss">
</style>
