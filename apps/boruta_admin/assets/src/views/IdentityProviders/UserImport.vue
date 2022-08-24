<template>
  <div class="user-import">
    <div class="container">
      <div class="ui segment">
        <form class="ui form" @submit.prevent="upload()">
          <div class="field">
            <label>Backend</label>
            <select v-model="backendId">
              <option :value="backend.id" v-for="backend in backends" :key="backend.id">{{ backend.name }}</option>
            </select>
          </div>
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
          <div class="field">
            <label>CSV file</label>
            <input type="file" @change="setFile" accept=".csv" />
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

export default {
  name: 'user-import',
  data () {
    return {
      file: null,
      options: {},
      backends: [],
      backendId: null,
      pending: false,
      importResult: null
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
    upload () {
      const { backendId, file, options } = this

      this.pending = true
      User.upload({ backendId, file, options }).then(result => {
        this.pending = false
        this.importResult = result
      }).catch(() => this.pending = false)
    }
  },
  watch: {
    file (file) {
      console.log(file)
    }
  }
}
</script>

<style scoped lang="scss">
.loading.segment {
  height: 36.35em;
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
