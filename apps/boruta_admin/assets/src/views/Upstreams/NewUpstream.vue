<template>
  <div class="new-upstream">
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Upstream ID</span>
                  <span class="description">not-assigned-yet</span>
                </div>
              </div>
            </div>
            <CurrentNodeUpstreams :node-name="upstream.node_name" />
            <router-link :to="{ name: 'service-registry' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <UpstreamForm :upstream="upstream" @submit="createUpstream()" @back="back()" action="Create" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Upstream from '../../models/upstream.model'
import CurrentNodeUpstreams from '../../components/CurrentNodeUpstreams.vue'
import UpstreamForm from '../../components/Forms/UpstreamForm.vue'

export default {
  name: 'new-upstream',
  components: {
    CurrentNodeUpstreams,
    UpstreamForm
  },
  data () {
    return {
      upstream: new Upstream(this.upstreamParamsFromQuery())
    }
  },
  methods: {
    upstreamParamsFromQuery () {
      const { node_name } = this.$route.query

      return Object.entries({ node_name }).reduce((params, [key, value]) => {
        if (value) params[key] = value
        return params
      }, {})
    },
    back () {
      this.$router.push({ name: 'service-registry' })
    },
    createUpstream () {
      return this.upstream.save().then(({ id }) => {
        this.$router.push({ name: 'edit-upstream', params: { upstreamId: id } })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-upstream {
  .field {
    position: relative;
    &.upstreams input {
      margin-right: 3em;
    }
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
