<template>
  <div class="configuration-file-upload">
    <div class="container">
      <div class="ui stackable grid">
        <div class="twelve wide column">
          <div class="upload-result">
            <div class="ui file-content segment">
              <TextEditor :content="fileContent" @codeUpdate="setContent" />
            </div>
          </div>
        </div>
        <div class="four wide column">
          <div class="sidebar">
            <form class="ui form" @submit.prevent="submit">
              <div class="ui segment">
                <div class="field">
                  <input type="file" @change="onFileChange" accept=".yml" :key="fileUpdates" />
                </div>
              </div>
              <div class="ui segment">
                <button type="submit" :to="{ name: 'new-backend' }" class="ui violet fluid create button">Upload <span v-if="edited">edited </span>configuration</button>
              </div>
            </form>
            <div class="ui results segment">
              <FormErrors :errors="errors" v-if="errors" :inline="true" />
              <div class="result" v-for="(errors, key) in result.errors">
                <h3>{{ key }}</h3>
                <FormErrors :errors="errors" :inline="true" v-if="errors" v-for="errors in errors"/>
                <div class="ui success message" v-if="!errors.length">Resources have been saved.</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import ConfigurationFile from '../../services/configuration-file.service.js'
import TextEditor from '../../components/Forms/TextEditor.vue'
import FormErrors from '../../components/Forms/FormErrors.vue'

export default {
  name: 'configuration-file-upload',
  components: {
    FormErrors,
    TextEditor
  },
  data () {
    return {
      file: null,
      result: {},
      fileContent: '',
      errors: null,
      edited: false
    }
  },
  mounted () {
    ConfigurationFile.get(this.$route.params.type).then(fileContent => {
      this.fileContent = fileContent
      this.file = new Blob([fileContent], {type : 'text/plain'})
    })
  },
  methods: {
    submit () {
      this.errors = null
      ConfigurationFile.upload(this.file).then(result => {
        this.result = result
        this.fileContent = result.file_content
        this.edited = false
      }).catch(({ errors }) => {
        this.errors = errors
      })
    },
    onFileChange (event) {
      this.file = event.target.files[0]
      new Response(this.file).text().then(fileContent => {
          this.fileContent = fileContent
      })
    },
    setContent (content) {
      this.file = new Blob([content], {type : 'text/plain'})
      this.edited = true
    }
  },
  watch: {
    fileUpdates() {
      this.file = null
    }
  }
}
</script>

<style scoped lang="scss">
.file-content {
  height: calc(100vh - 162px);
  margin: 0 !important;
}
.results {
  height: calc(100vh - 340px);
  margin: 0 !important;
  overflow: hidden;
  overflow-y: scroll;
}
</style>
