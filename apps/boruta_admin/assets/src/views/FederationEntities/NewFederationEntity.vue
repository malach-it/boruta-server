<template>
  <div class="new-federation-entity">
    <div class="container">
      <div class="ui stackable grid">
        <div class="four wide column">
          <div class="sidebar">
            <router-link :to="{ name: 'federation-entity-list' }" class="ui right floated button">Back</router-link>
          </div>
        </div>
        <div class="twelve wide column">
          <FederationEntityForm :federationEntity="federationEntity" @submit="createFederationEntity()" @back="back()" action="Create" />
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import FederationEntity from '../../models/federation-entity.model'
import FederationEntityForm from '../../components/Forms/FederationEntityForm.vue'

export default {
  name: 'federation-entitys',
  components: {
    FederationEntityForm
  },
  data () {
    return {
      federationEntity: new FederationEntity()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'federation-entity-list' })
    },
    createFederationEntity () {
      return this.federationEntity.save().then(() => {
        this.$router.push({ name: 'federation-entity-list' })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-federation-entity {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
