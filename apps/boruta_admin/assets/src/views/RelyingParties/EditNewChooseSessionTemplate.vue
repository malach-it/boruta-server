<template>
  <div class="container choose-session-template">
    <div class="field">
      <TextEditor :content="content" @codeUpdate="setContent" />
    </div>
    <div class="ui segment">
      <button v-on:click="update()" class="ui large violet right floated button">Save</button>
      <button v-if="template.id" v-on:click="destroy()" class="ui large red right floated button">Reset</button>
      <router-link :to="{ name: 'edit-relying-party', params: { relyingPartyId: relyingParty.id } }" class="ui large blue button">Back</router-link>
    </div>
  </div>
</template>

<script>
import Template from '../../models/template.model'
import RelyingParty from '../../models/relying-party.model'
import TextEditor from '../../components/Forms/TextEditor.vue'

export default {
  name: 'choose-session-template',
  components: {
    TextEditor
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
    Template.get(relyingPartyId, 'choose_session').then((template) => {
      this.template = template
      this.content = template.content
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
    },
    destroy () {
      if (confirm('Are you sure you want to reset the template?')) {
        this.template.destroy().then((template) => {
          this.template = template
          this.content = template.content
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
.choose-session-template {
  height: 100%;
  display: flex;
  flex-direction: column;
  .field {
    flex: 1;
  }
}
</style>
