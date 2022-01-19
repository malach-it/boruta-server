<template>
  <div class="edit-registration-template">
    <div class="main header">
      <h1>Edit {{ relyingParty.name }} registration template</h1>
      <div class="ui segment">
        <router-link :to="{ name: 'edit-relying-party', relyingPartyId: relyingParty.id }">edit relying party</router-link> > registration template
      </div>
    </div>
    <TextEditor :content="content" @codeUpdate="setContent" />
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
      content: 'Hello world !',
      relyingParty: new RelyingParty()
    }
  },
  methods: {
    back () {
      this.$router.push({ name: 'relying-party-list' })
    },
    setContent (code) {
      this.content = code
    }
  }
}
</script>

<style scoped lang="scss">
.edit-registration-template {
  position: relative;
  height: 100%;
}
.preview {
  padding: 15px;
}
</style>
