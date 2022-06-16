<template>
  <div class="container edit-edit-user-template">
    <Toaster :active="success" message="Template has been updated" type="success" />
    <div class="field">
      <TextEditor :content="content" @codeUpdate="setContent" />
    </div>
    <div class="ui segment">
      <button v-on:click="update()" class="ui violet right floated button">Save</button>
      <button v-if="template.id" v-on:click="destroy()" class="ui red right floated button">Reset</button>
      <router-link :to="{ name: 'edit-relying-party', params: { relyingPartyId: relyingParty.id } }" class="ui blue button">Back</router-link>
    </div>
  </div>
</template>

<script>
import Template from '../../models/template.model'
import RelyingParty from '../../models/relying-party.model'
import TextEditor from '../../components/Forms/TextEditor.vue'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'edit-edit-user-template',
  components: {
    TextEditor,
    Toaster
  },
  mounted () {
    const { relyingPartyId } = this.$route.params
    RelyingParty.get(relyingPartyId).then((relyingParty) => {
      this.relyingParty = relyingParty
    })
    Template.get(relyingPartyId, 'edit_user').then((template) => {
      this.template = template
      this.content = template.content
    })
  },
  data () {
    return {
      content: '',
      relyingParty: new RelyingParty(),
      template: new Template(),
      success: false
    }
  },
  methods: {
    setContent(code) {
      this.template.content = code
    },
    update () {
      this.success = false
      this.template.save().then(() => {
        this.success = true
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
.edit-edit-user-template {
  height: 100%;
  display: flex;
  flex-direction: column;
  .field {
    flex: 1;
  }
}
</style>
