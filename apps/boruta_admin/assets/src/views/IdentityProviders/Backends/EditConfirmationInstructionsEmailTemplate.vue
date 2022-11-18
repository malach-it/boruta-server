<template>
  <div class="container edit-confirmation-instructions-email-template">
    <Toaster :active="success" message="Template has been updated" type="success" />
    <div class="ui segment">
      <h2>Text content</h2>
      <TextEditor :content="txtContent" @codeUpdate="setTxtContent" />
    </div>
    <div class="ui segment">
      <h2>HTML content</h2>
      <TextEditor :content="htmlContent" @codeUpdate="setHtmlContent" />
    </div>
    <div class="ui segment">
      <button v-on:click="update()" class="ui violet right floated button">Save</button>
      <button v-if="template.id" v-on:click="destroy()" class="ui red right floated button">Reset</button>
      <router-link :to="{ name: 'edit-backend', params: { backendId: backend.id } }" class="ui blue button">Back</router-link>
    </div>
  </div>
</template>

<script>
import EmailTemplate from '../../../models/email-template.model'
import Backend from '../../../models/backend.model'
import TextEditor from '../../../components/Forms/TextEditor.vue'
import Toaster from '../../../components/Toaster.vue'

export default {
  name: 'edit-confirmation-instructions-email-template',
  components: {
    TextEditor,
    Toaster
  },
  mounted () {
    const { backendId } = this.$route.params
    Backend.get(backendId).then((backend) => {
      this.backend = backend
    })
    EmailTemplate.get(backendId, 'confirmation_instructions').then((template) => {
      this.template = template
      this.txtContent = template.txt_content
      this.htmlContent = template.html_content
    })
  },
  data () {
    return {
      txtContent: '',
      htmlContent: '',
      backend: new Backend(),
      template: new EmailTemplate(),
      success: false
    }
  },
  methods: {
    setTxtContent(code) {
      this.template.txt_content = code
    },
    setHtmlContent(code) {
      this.template.html_content = code
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
          this.txtContent = template.txt_content
          this.htmlContent = template.html_content
        })
      }
    }
  }
}
</script>

<style scoped lang="scss">
</style>
