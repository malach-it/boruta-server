<template>
  <div class="edit-relying-party">
    <div class="main header">
      <h1>Edit a relying party</h1>
    </div>
    <div class="ui container">
      <div class="ui large segment">
        <div class="ui attribute list">
          <div class="item">
            <span class="header">Relying party ID</span>
            <span class="description">{{ relyingParty.id }}</span>
          </div>
          <div class="item">
            <span class="header">Name</span>
            <span class="description">{{ relyingParty.name }}</span>
          </div>
        </div>
      </div>
      <RelyingPartyForm :relyingParty="relyingParty" @submit="updateRelyingParty()" @back="back()" action="Update" />
    </div>
  </div>
</template>

<script>
import RelyingParty from '../../models/relying-party.model'
import RelyingPartyForm from '../../components/Forms/RelyingPartyForm.vue'

export default {
  name: 'edit-relying-party',
  components: {
    RelyingPartyForm
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
  },
  data () {
    return {
      relyingParty: new RelyingParty()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'relying-party-list' })
    },
    updateRelyingParty () {
      return this.relyingParty.save().then(() => {
        this.$router.push({ name: 'relying-party-list' })
      }).catch()
    }
  }
}
</script>
