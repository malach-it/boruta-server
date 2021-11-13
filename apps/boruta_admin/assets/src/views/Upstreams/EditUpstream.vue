<template>
  <div class="edit-upstream">
    <div class="main header">
      <h1>Edit Upstream</h1>
    </div>
    <div class="ui container">
      <UpstreamForm :upstream="upstream" @submit="updateUpstream()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Upstream from '@/models/upstream.model'
import UpstreamForm from '@/components/UpstreamForm.vue'

export default {
  name: 'upstreams',
  components: {
    UpstreamForm
  },
  mounted () {
    const { upstreamId } = this.$route.params
    Upstream.get(upstreamId).then((upstream) => {
      this.upstream = upstream
    })
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
    updateUpstream () {
      return this.upstream.save().then(() => {
        this.$router.push({ name: 'upstream-list' })
      }).catch(console.debug)
    }
  }
}
</script>
