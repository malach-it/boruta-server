<template>
  <div class="field">
    <label>Relying party</label>
    <select v-model="currentRelyingPartyId">
      <option v-for="relyingPartyOption in relyingParties" :value="relyingPartyOption.id" :key="relyingPartyOption.id" :selected="relyingPartyOption.id == currentRelyingPartyId">
        {{ relyingPartyOption.name }}
      </option>
    </select>
  </div>
</template>

<script>
import RelyingParty from '@/models/relying-party.model'

export default {
  name: 'RelyingPartyField',
  props: ['relyingParty'],
  mounted () {
    RelyingParty.all().then((relyingParties) => {
      this.relyingParties = relyingParties
    })
  },
  data () {
    return {
      relyingParties: []
    }
  },
  computed: {
    currentRelyingPartyId: {
      get () {
        return this.relyingParty.id
      },
      set (relyingPartyId) {
        return this.$emit('relyingPartyChange', this.relyingParties.find(({ id }) => id === relyingPartyId))
      }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped lang="scss">
</style>
