<template>
  <div class="federation-entity-list">
    <Toaster :active="created" message="Federation entity has been created" type="success" />
    <Toaster :active="rotated" message="Federation entity has been rotated" type="success" />
    <Toaster :active="error" :message="error" type="error" />
    <Toaster :active="deleted" message="Federation entity has been deleted" type="warning" />
    <router-link class="ui violet main create button" :to="{ name: 'new-federation-entity' }">Add a federation entity</router-link>
    <div class="container">
      <h2>Federation entities</h2>
      <div class="ui three column stackable grid">
        <div class="ui column" v-for="federationEntity in federationEntities">
          <div class="ui federation-entity segment">
            <div class="actions">
              <a v-on:click="deleteFederationEntity(federationEntity)" class="ui tiny red button">delete</a>
            </div>
            <div class="ui attribute list">
              <div class="item">
                <span class="header">Federation entity ID</span>
                <span class="description">{{ federationEntity.id }}</span>
              </div>
              <div class="item">
                <span class="header">Organization name</span>
                <span class="description">{{ federationEntity.organization_name }}</span>
              </div>
              <div class="item">
                <span class="header">Authorities</span>
                <span class="description" v-for="authority in federationEntity.authorities">{{ authority.issuer }} - {{ authority.sub }}</span>
              </div>
              <div class="item">
                <span class="header">Trust mark logo uri</span>
                <span class="description">{{ federationEntity.trust_mark_logo_uri }}</span>
              </div>
            </div>
            <h3>Public key</h3>
            <pre>{{ federationEntity.public_key }}</pre>
            <div class="ui default label" v-if="federationEntity.is_default">default</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import FederationEntity from '../../models/federation-entity.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'federation-entity-list',
  components: {
    Toaster
  },
  data () {
    return {
      created: false,
      rotated: false,
      deleted: false,
      error: false,
      federationEntities: []
    }
  },
  mounted () {
    this.getFederationEntities()
  },
  methods: {
    getFederationEntities () {
      FederationEntity.all().then(federationEntities => {
        this.federationEntities = federationEntities
      })
    },
    setDefault (federationEntity) {
      federationEntity.is_default = true
      federationEntity.save().then((federationEntity) => {
        if (federationEntity.is_default) {
          this.federationEntities.forEach(federationEntity => federationEntity.is_default = false)
          federationEntity.is_default = true
        }
      }).catch(() => {
        federationEntity.is_default = false
      })
    },
    rotate (federationEntity) {
      if (!confirm('Are you sure?')) return
      this.rotated = false
      federationEntity.rotate().then(() => {
        this.rotated = true
      })
    },
    deleteFederationEntity (federationEntity) {
      if (!confirm('Are you sure?')) return

      this.deleted = false
      this.error = false
      federationEntity.destroy().then(() => {
        this.deleted = true
        this.federationEntities.splice(this.federationEntities.indexOf(federationEntity), 1)
      }).catch(error => this.error = error.message)
    }
  }
}
</script>

<style scoped lang="scss">
.federation-entity {
  padding-bottom: 1.6em;
  pre {
    overflow: hidden;
    overflow-x: scroll;
  }
  .default.label {
    position: absolute;
    bottom: 0;
    right: 0;
  }
}
</style>


