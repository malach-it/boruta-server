<template>
  <div class="container edit-session-template">
    <div class="main header">
      <h1>Edit {{ relyingParty.name }} session template</h1>
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
  name: 'edit-session-template',
  components: {
    TextEditor
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
    Template.get(relyingPartyId, 'new_session').then((template) => {
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
.edit-session-template {
  height: 100%;
  display: flex;
  flex-direction: column;
  .field {
    flex: 1;
  }
}
</style>
