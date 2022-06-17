<template>
  <div class="new-identity-provider">
    <div class="ui container">
      <IdentityProviderForm :identityProvider="identityProvider" @submit="createIdentityProvider()" @back="back()" action="Create" />
    </div>
  </div>
</template>

<script>
import IdentityProvider from '../../models/identity-provider.model'
import IdentityProviderForm from '../../components/Forms/IdentityProviderForm.vue'

export default {
  name: 'new-identity-provider',
  components: {
    IdentityProviderForm
  },
  data () {
    return {
      identityProvider: new IdentityProvider()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'identity-provider-list' })
    },
    createIdentityProvider () {
      return this.identityProvider.save().then(() => {
        this.$router.push({ name: 'identity-provider-list' })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-identity-provider {
  .field {
    position: relative;
    &.identity-providers input {
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
