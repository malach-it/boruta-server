<template>
  <div class="edit-identity-provider">
    <Toaster :active="success" message="identity provider has been updated" type="success" />
    <div class="ui container">
      <div class="ui segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">identity provider ID</span>
            <span class="description">{{ identityProvider.id }}</span>
          </div>
          <div class="item">
            <span class="header">Name</span>
            <span class="description">{{ identityProvider.name }}</span>
          </div>
        </div>
      </div>
      <IdentityProviderForm :identityProvider="identityProvider" @submit="updateIdentityProvider()" @back="back()" action="Update" />
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
