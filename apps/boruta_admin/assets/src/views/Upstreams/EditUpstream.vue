<template>
  <div class="edit-upstream">
    <Toaster :active="success" message="Upstream has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Upstream ID</span>
            <span class="description">{{ upstream.id }}</span>
          </div>
        </div>
      </div>
      <UpstreamForm :upstream="upstream" @submit="updateUpstream()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import Upstream from '../../models/upstream.model'
import UpstreamForm from '../../components/Forms/UpstreamForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'upstreams',
  components: {
    UpstreamForm,
    Toaster
  },
  mounted () {
    const { upstreamId } = this.$route.params
    Upstream.get(upstreamId).then((upstream) => {
      this.upstream = upstream
    })
  },
  data () {
    return {
      upstream: new Upstream(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'upstream-list' })
    },
    updateUpstream () {
      this.success = false
      return this.upstream.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
