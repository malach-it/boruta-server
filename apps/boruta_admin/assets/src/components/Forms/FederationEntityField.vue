<template>
  <div class="field">
    <label>federation entity</label>
    <select v-model="currentFederationEntityId">
      <option v-for="federationEntityOption in federationEntities" :value="federationEntityOption.id" :key="federationEntityOption.id" :selected="federationEntityOption.id == currentFederationEntityId">
        {{ federationEntityOption.organization_name }}
      </option>
    </select>
  </div>
</template>

<script>
import FederationEntity from '../../models/federation-entity.model'

export default {
  name: 'FederationEntityField',
  props: ['federationEntity'],
  mounted () {
    FederationEntity.all().then((federationEntities) => {
      this.federationEntities = federationEntities
    })
  },
  data () {
    return {
      federationEntities: []
    }
  },
  computed: {
    currentFederationEntityId: {
      get () {
        return this.federationEntity.id
      },
      set (federationEntityId) {
        return this.$emit('federationEntityChange', this.federationEntities.find(({ id }) => id === federationEntityId))
      }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped lang="scss">
</style>
