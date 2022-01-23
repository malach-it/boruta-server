<template>
  <div class="upstream-list">
    <router-link :to="{ name: 'new-upstream' }" class="ui teal main create button">Add an upstream</router-link>
    <div class="container">
      <div class="ui three column upstreams stackable grid" v-if="upstreams.length">
        <div v-for="upstream in upstreams" :key="upstream.id" class="column">
        <div class="ui large upstream highlightable segment">
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
                <span v-for="path in upstream.uris" class="ui olive label" :key="path.uri">
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
</template>

<script>
import Upstream from '../../models/upstream.model'

export default {
  name: 'upstream-list',
  data () {
    return { upstreams: [] }
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
      if (confirm('Are yousure ?')) {
        upstream.destroy().then(() => {
          this.upstreams.splice(this.upstreams.indexOf(upstream), 1)
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
</style>
