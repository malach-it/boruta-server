<template>
  <div class="field">
    <label>identity provider</label>
    <select v-model="currentIdentityProviderId">
      <option v-for="identityProviderOption in identityProviders" :value="identityProviderOption.id" :key="identityProviderOption.id" :selected="identityProviderOption.id == currentIdentityProviderId">
        {{ identityProviderOption.name }}
      </option>
    </select>
  </div>
</template>

<script>
import IdentityProvider from '../../models/identity-provider.model'

export default {
  name: 'IdentityProviderField',
  props: ['identityProvider'],
  mounted () {
    IdentityProvider.all().then((identityProviders) => {
      this.identityProviders = identityProviders
    })
  },
  data () {
    return {
      identityProviders: []
    }
  },
  computed: {
    currentIdentityProviderId: {
      get () {
        return this.identityProvider.id
      },
      set (identityProviderId) {
        return this.$emit('identityProviderChange', this.identityProviders.find(({ id }) => id === identityProviderId))
      }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped lang="scss">
</style>
