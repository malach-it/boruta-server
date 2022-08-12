<template>
  <div class="backend-list">
    <Toaster :active="deleted" message="backend has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <router-link :to="{ name: 'new-backend' }" class="ui violet main create button">Add a backend</router-link>
    <div class="container">
      <div class="ui info message">
        Backends act as user registries, identity providers are connected to them in order to manage identities.
      </div>
      <div class="ui three column backends stackable grid" v-if="backends.length">
        <div v-for="backend in backends" :key="backend.id" class="column">
          <FormErrors v-if="backend.errors" :errors="backend.errors" />
          <div class="ui backend highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-backend', params: { backendId: backend.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteBackend(backend)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Name</span>
                <span class="description">{{ backend.name }}</span>
              </div>
              <div class="item">
                <span class="header">Type</span>
                <span class="description">{{ backend.type }}</span>
              </div>
              <div class="item">
                <span class="header">Backend ID</span>
                <span class="description">{{ backend.id }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import Backend from '../../models/backend.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'backend-list',
  components: {
    Toaster
  },
  data () {
    return {
      backends: [],
      errorMessage: false,
      deleted: false
    }
  },
  mounted () {
    this.getBackends()
  },
  methods: {
    getBackends () {
      Backend.all().then((backends) => {
        this.backends = backends
      })
    },
    deleteBackend (backend) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      backend.destroy().then(() => {
        this.deleted = true
        this.backends.splice(this.backends.indexOf(backend), 1)
      }).catch((error) => {
        this.errorMessage = error.message
      })
    }
  }
}
</script>

<style scoped lang="scss">
</style>
