<template>
  <div class="edit-registration-template">
    <div class="main header">
      <h1>Edit {{ relyingParty.name }} registration template</h1>
      <div class="ui segment">
        <router-link :to="{ name: 'edit-relying-party', relyingPartyId: relyingParty.id }">edit relying party</router-link> > registration template
      </div>
    </div>
    <div class="container">
      <div class="ui grid">
        <div class="eight wide column">
          <TextEditor content="Hello world" />
        </div>
        <div class="eight wide column">
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import RelyingParty from '../../models/relying-party.model'
import TextEditor from '../../components/Forms/TextEditor.vue'

export default {
  name: 'edit-registration-template',
  components: {
    TextEditor
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
