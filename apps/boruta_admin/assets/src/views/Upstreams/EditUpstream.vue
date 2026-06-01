<template>
  <div class="edit-upstream">
    <Toaster :active="success" message="Upstream has been updated" type="success" />
    <div class="container">
      <div class="ui error message" v-if="error">
        {{ error }}
      </div>
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Upstream ID</span>
                  <span class="description">{{ upstream.id }}</span>
                </div>
              </div>
            </div>
            <CurrentNodeUpstreams :node-name="upstream.node_name" />
            <router-link :to="{ name: 'service-registry' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <UpstreamForm :upstream="upstream" @submit="updateUpstream()" @back="back()" action="Update" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Upstream from '../../models/upstream.model'
import CurrentNodeUpstreams from '../../components/CurrentNodeUpstreams.vue'
import UpstreamForm from '../../components/Forms/UpstreamForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'upstreams',
  components: {
    CurrentNodeUpstreams,
    UpstreamForm,
    Toaster
  },
  mounted () {
    const { upstreamId } = this.$route.params
    Upstream.get(upstreamId).then((upstream) => {
      this.upstream = upstream
    }).catch((error) => {
      this.error = error.response?.data?.message || error.message
    })
  },
  data () {
    return {
      upstream: new Upstream(),
      success: false,
      error: null
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'service-registry' })
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
