<template>
  <div class="container edit-edit-reset-password-template">
    <div class="main header">
      <h1>Edit {{ relyingParty.name }} reset_password</h1>
    </div>
    <div class="field">
      <TextEditor :content="content" @codeUpdate="setContent" />
    </div>
    <div class="ui actions segment">
      <button v-on:click="update()" class="ui large violet right floated button">Save</button>
      <router-link :to="{ name: 'edit-relying-party', params: { relyingPartyId: relyingParty.id } }" class="ui large blue button">Back</router-link>
    </div>
  </div>
</template>

<script>
import Template from '../../models/template.model'
import RelyingParty from '../../models/relying-party.model'
import TextEditor from '../../components/Forms/TextEditor.vue'

export default {
  name: 'edit-edit-reset-password-template',
  components: {
    TextEditor
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
    Template.get(relyingPartyId, 'edit_reset_password').then((template) => {
      this.template = template
      this.content = template.content
      console.log(template)
    })
  },
  data () {
    return {
      content: '',
      relyingParty: new RelyingParty(),
      template: new Template()
    }
  },
  methods: {
    setContent(code) {
      this.template.content = code
    },
    update () {
      this.template.save().then(() => {
        this.$router.push({ name: 'edit-relying-party', params: { relyingPartyId: this.relyingParty.id } })
      })
    }
  }
}
</script>

<style scoped lang="scss">
.edit-registration-template {
  height: 100%;
  display: flex;
  flex-direction: column;
  .field {
    flex: 1;
  }
}
</style>
