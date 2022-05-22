<template>
  <div class="edit-relying-party">
    <Toaster :active="success" message="Relying party has been updated" type="success" />
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
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-relying-party',
  components: {
    RelyingPartyForm,
    Toaster
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
  },
  data () {
    return {
      relyingParty: new RelyingParty(),
      success: false
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'relying-party-list' })
    },
    updateRelyingParty () {
      this.success = false
      return this.relyingParty.save().then(() => {
        this.success = true
      }).catch()
    }
  }
}
</script>
