<template>
  <div class="user-import">
    <div class="container">
      <div class="ui segment">
        <FormErrors :errors="importErrors" v-if="importErrors" />
        <form class="ui form" @submit.prevent="upload()">
          <h3>Base fields</h3>
          <div class="field">
            <label>username header</label>
            <input type="text" v-model="options.usernameHeader" placeholder="username" />
          </div>
          <div class="field">
            <label>password header</label>
            <input type="text" v-model="options.passwordHeader" placeholder="password" />
          </div>
          <div class="field">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="options.hashPassword">
              <label>Hash password</label>
            </div>
          </div>
          <h3>Metadata fields</h3>
          <div class="field">
            <div v-for="header in options.metadataHeaders" class="metadata-header">
              <div class="field">
                <label>metadata header</label>
                <input type="text" v-model="header.origin" placeholder="origin" />
              </div>
              <div class="field">
                <label>metadata field</label>
                <input type="text" v-model="header.target" placeholder="target" />
              </div>
              <hr />
            </div>
            <a class="ui blue fluid button" @click="addMetadataHeader()">Add metadataHeader</a>
          </div>
          <div class="field">
            <label>Backend</label>
            <select v-model="backendId">
              <option :value="backend.id" v-for="backend in backends" :key="backend.id">{{ backend.name }}</option>
            </select>
          </div>
          <div class="field">
            <label>CSV file</label>
            <input type="file" @change="setFile" accept=".csv" :key="fileUpdates" />
          </div>
          <hr />
          <button class="ui right floated violet button" type="submit">upload</button>
          <router-link :to="{ name: 'user-list' }" class="ui button">Back</router-link>
        </form>
      </div>
      <div class="ui center aligned loading segment" v-if="pending">
        <h2>Processing request, please wait and do not leave the page...</h2>
      </div>
      <div class="ui segment" v-if="!pending && importResult">
        <h2>Import results</h2>
        <div class="ui stackable grid">
          <div class="ten wide filter-form column">
            <div class="import-errors" v-if="importResult.errors.length">
              <div class="ui error message" v-for="error in importResult.errors">
                <strong>Line {{ error.line }}</strong>
                <ul class="list">
                  <li v-for="key in Object.keys(error.changeset)" :key="key">
                    <strong>{{ key }} </strong> {{ error.changeset[key][0] }}
                  </li>
                </ul>
              </div>
            </div>
            <div class="ui placeholder success message segment" v-else>
              <div class="ui icon header">
                <i class="ui large check circle icon"></i> All clear.
              </div>
            </div>
          </div>
          <div class="six wide import-counts column">
            <div class="counts">
              <label>Success count <span>{{ importResult.success_count }}</span></label>
              <label>Error count <span>{{ importResult.error_count }}</span></label>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import User from '../../models/user.model'
import Backend from '../../models/backend.model'
import Toaster from '../../components/Toaster.vue'
import FormErrors from '../../components/Forms/FormErrors.vue'

export default {
  name: 'user-import',
  components: {
    FormErrors
  },
  data () {
    return {
      fileUpdates: 0,
      file: null,
      options: {metadataHeaders: []},
      backends: [],
      backendId: null,
      pending: false,
      importResult: null,
      importErrors: null
    }
  },
  mounted () {
    Backend.all().then((backends) => {
      this.backends = backends
    })
  },
  methods: {
    setFile (event) {
      this.file = event.target.files[0]
    },
    addMetadataHeader () {
      this.options.metadataHeaders.push({})
    },
    upload () {
      const { backendId, file, options } = this

      this.pending = true
      User.upload({ backendId, file, options }).then(result => {
        this.fileUpdates++
        this.pending = false
        this.importResult = result
      }).catch((errors) => {
        this.fileUpdates++
        this.pending = false
        this.importErrors = errors
      })
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
.loading.segment {
  height: 24.35em;
  color: inherit!important;
}
.import-counts {
  display: flex!important;
  align-items: center;
  justify-content: center;
  flex-direction: column;
  .counts {
    padding: 1rem;
    text-align: center;
  }
  label {
    display: block;
    font-size: 1.3rem;
    margin: .5rem;
    span {
      font-weight: bold;
      display: block;
      font-size: 1.5rem;
    }
  }
}
.import-errors {
  max-height: 31em;
  overflow: hidden;
  overflow-y: scroll;
  padding-right: 1em;
}
</style>
