<template>
  <div class="upstream-list">
    <div class="ui container">
      <h1>Upstreams</h1>
      <div v-for="upstream in upstreams" class="ui big upstream segments" :key="upstream.id">
        <div class="ui segment">
          <div class="actions">
            <router-link
              :to="{ name: 'edit-upstream', params: { upstreamId: upstream.id } }"
              class="ui tiny blue button">edit</router-link>
            <a v-on:click="deleteUpstream(upstream)" class="ui tiny red button">delete</a>
          </div>
          <p><strong>Upstream ID :</strong> {{ upstream.id }}</p>
          <p><strong>Base URL :</strong> {{ upstream.scheme }}://{{ upstream.host }}:{{ upstream.port }}</p>
          <span v-for="path in upstream.uris" class="ui olive label" :key="path.uri">
            {{ path.uri }}
          </span>
        </div>
      </div>
      <div class="main actions">
        <router-link :to="{ name: 'new-upstream' }" class="ui teal big button">Add an upstream</router-link>
      </div>
    </div>
  </div>
</template>

<script>
import Upstream from '@/models/upstream.model'

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
