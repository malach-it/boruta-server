<template>
  <div class="new-upstream">
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <router-link :to="{ name: 'upstream-list' }" class="ui right floated button">Back</router-link>
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
import UpstreamForm from '../../components/Forms/UpstreamForm.vue'

export default {
  name: 'new-upstream',
  components: {
    UpstreamForm
  },
  data () {
    return {
      upstream: new Upstream()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'upstream-list' })
    },
    createUpstream () {
      return this.upstream.save().then(() => {
        this.$router.push({ name: 'upstream-list' })
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
