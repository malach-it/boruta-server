<template>
  <div class="container edit-invite-organization-member-email-template">
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
      <router-link :to="{ name: 'edit-organization', params: { organizationId: organization.id } }" class="ui blue button" v-if="organization.isPersisted">Back</router-link>
    </div>
  </div>
</template>

<script>
import EmailTemplate from '../../../models/email-template.model'
import Organization from '../../../models/organization.model'
import TextEditor from '../../../components/Forms/TextEditor.vue'
import Toaster from '../../../components/Toaster.vue'

export default {
  name: 'edit-invite-organization-member-email-template',
  components: {
    TextEditor,
    Toaster
  },
  mounted () {
    const { organizationId } = this.$route.params
    Organization.get(organizationId).then((organization) => {
      this.organization = organization
    })
    EmailTemplate.get(organizationId, 'invite_organization_member').then((template) => {
      this.template = template
      this.txtContent = template.txt_content
      this.htmlContent = template.html_content
    })
  },
  data () {
    return {
      txtContent: '',
      htmlContent: '',
      organization: new Organization(),
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
