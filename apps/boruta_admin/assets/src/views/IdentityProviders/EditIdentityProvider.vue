<template>
  <div class="edit-identity-provider">
    <Toaster :active="success" message="identity provider has been updated" type="success" />
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <div class="ui segment">
              <div class="ui attribute list">
                <div class="item">
                  <span class="header">Name</span>
                  <span class="description">{{ identityProvider.name }}</span>
                </div>
                <div class="item">
                  <span class="header">identity provider ID</span>
                  <span class="description">{{ identityProvider.id }}</span>
                </div>
                <div class="item">
                  <span class="header">Backend</span>
                  <span class="description"><router-link :to="{ name: 'edit-backend', params: { backendId: identityProvider.backend.id } }">{{ identityProvider.backend.name }}</router-link></span>
                </div>
              </div>
            </div>
            <router-link :to="{ name: 'identity-provider-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <IdentityProviderForm :identityProvider="identityProvider" @submit="updateIdentityProvider()" @back="back()" action="Update" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import IdentityProvider from '../../models/identity-provider.model'
import IdentityProviderForm from '../../components/Forms/IdentityProviderForm.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-identity-provider',
  components: {
    IdentityProviderForm,
    Toaster
  },
  mounted () {
    const { identityProviderId } = this.$route.params
    IdentityProvider.get(identityProviderId).then((identityProvider) => {
      this.identityProvider = identityProvider
    })
  },
  data () {
    return {
      identityProvider: new IdentityProvider(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'identity-provider-list' })
    },
    updateIdentityProvider () {
      this.success = false
      return this.identityProvider.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
