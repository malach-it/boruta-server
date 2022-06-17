<template>
  <div class="identityProvider-list">
    <Toaster :active="deleted" message="identity provider has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <router-link :to="{ name: 'new-identity-provider' }" class="ui teal main create button">Add a identity provider</router-link>
    <div class="container">
      <div class="ui three column identityProviders stackable grid" v-if="identityProviders.length">
        <div v-for="identityProvider in identityProviders" :key="identityProvider.id" class="column">
          <FormErrors v-if="identityProvider.errors" :errors="identityProvider.errors" />
          <div class="ui identityProvider highlightable segment">
            <div class="actions">
              <router-link
                :to="{ name: 'edit-identity-provider', params: { identityProviderId: identityProvider.id } }"
                class="ui tiny blue button">edit</router-link>
              <a v-on:click="deleteIdentityProvider(identityProvider)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Name</span>
                <span class="description">{{ identityProvider.name }}</span>
              </div>
              <div class="item">
                <span class="header">Type</span>
                <span class="description">{{ identityProvider.type }}</span>
              </div>
              <div class="item">
                <span class="header">IdentityProvider ID</span>
                <span class="description">{{ identityProvider.id }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import IdentityProvider from '../../models/identity-provider.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'identity-provider-list',
  components: {
    Toaster
  },
  data () {
    return {
      identityProviders: [],
      errorMessage: false,
      deleted: false
    }
  },
  mounted () {
    this.getIdentityProviders()
  },
  methods: {
    getIdentityProviders () {
      IdentityProvider.all().then((identityProviders) => {
        this.identityProviders = identityProviders
      })
    },
    deleteIdentityProvider (identityProvider) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      identityProvider.destroy().then(() => {
        this.deleted = true
        this.identityProviders.splice(this.identityProviders.indexOf(identityProvider), 1)
      }).catch((error) => {
        this.errorMessage = error.message
      })
    }
  }
}
</script>

<style scoped lang="scss">
</style>
