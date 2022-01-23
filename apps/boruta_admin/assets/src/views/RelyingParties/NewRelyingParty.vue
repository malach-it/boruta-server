<template>
  <div class="new-relying-party">
    <div class="ui container">
      <RelyingPartyForm :relyingParty="relyingParty" @submit="createRelyingParty()" @back="back()" action="Create" />
    </div>
  </div>
</template>

<script>
import RelyingParty from '../../models/relying-party.model'
import RelyingPartyForm from '../../components/Forms/RelyingPartyForm.vue'

export default {
  name: 'new-relying-party',
  components: {
    RelyingPartyForm
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
    createRelyingParty () {
      return this.relyingParty.save().then(() => {
        this.$router.push({ name: 'relying-party-list' })
      }).catch()
    }
  }
}
</script>

<style scoped lang="scss">
.new-relying-party {
  .field {
    position: relative;
    &.relying-partys input {
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
