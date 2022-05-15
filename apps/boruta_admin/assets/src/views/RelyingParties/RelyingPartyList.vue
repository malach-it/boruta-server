<template>
  <div class="relyingParty-list">
    <router-link :to="{ name: 'new-relying-party' }" class="ui teal main create button">Add a relying party</router-link>
    <div class="container">
      <div class="ui three column relyingParties stackable grid" v-if="relyingParties.length">
        <div v-for="relyingParty in relyingParties" :key="relyingParty.id" class="column">
        <div class="ui large relyingParty highlightable segment">
          <div class="actions">
            <router-link
              :to="{ name: 'edit-relying-party', params: { relyingPartyId: relyingParty.id } }"
              class="ui tiny blue button">edit</router-link>
            <a v-on:click="deleteRelyingParty(relyingParty)" class="ui tiny red button">delete</a>
          </div>
          <div class="ui attribute list">
            <div class="item">
              <span class="header">Name</span>
              <span class="description">{{ relyingParty.name }}</span>
            </div>
            <div class="item">
              <span class="header">Type</span>
              <span class="description">{{ relyingParty.type }}</span>
            </div>
            <div class="item">
              <span class="header">RelyingParty ID</span>
              <span class="description">{{ relyingParty.id }}</span>
            </div>
          </div>
          <FormErrors v-if="relyingParty.errors" :errors="relyingParty.errors" />
        </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import FormErrors from '../../components/Forms/FormErrors.vue'
import RelyingParty from '../../models/relying-party.model'

export default {
  name: 'relying-party-list',
  components: {
    FormErrors
  },
  data () {
    return { relyingParties: [] }
  },
  mounted () {
    this.getRelyingParties()
  },
  methods: {
    getRelyingParties () {
      RelyingParty.all().then((relyingParties) => {
        this.relyingParties = relyingParties
      })
    },
    deleteRelyingParty (relyingParty) {
      if (confirm('Are you sure ?')) {
        relyingParty.destroy().then(() => {
          this.relyingParties.splice(this.relyingParties.indexOf(relyingParty), 1)
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
</style>
