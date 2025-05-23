<template>
  <div id="scope-list">
    <Toaster :active="saved" message="Scope has been saved" type="success" />
    <Toaster :active="deleted" message="Scope has been deleted" type="warning" />
    <Toaster :active="errorMessage" :message="errorMessage" type="error" />
    <div class="container">
      <div class="ui info message">
        Scopes are here the ones that are to be requested by the client. They are to be public, accessible to everyone, or private, granted only having a priviledge user or client.
      </div>
      <div class="ui segments" v-if="scopes.length">
        <div v-for="(scope, index) in scopes" class="ui mini highlightable segment" :key="index">
          <div v-if="scope.edit">
            <form @submit.prevent="saveScope(scope)" class="ui form">
              <div class="ui stackable grid">
                <div class="four wide column">
                  <div class="ui field" :class="{ 'error': scope.errors && scope.errors.name }">
                    <input type="text" v-model="scope.name" placeholder="iam:a:scope">
                    <em v-if="scope.errors && scope.errors.name" class="error-message">{{ scope.errors.name[0] }}</em>
                  </div>
                </div>
                <div class="four wide column">
                  <div class="ui field" :class="{ 'error': scope.errors && scope.errors.label }">
                    <input type="text" v-model="scope.label" placeholder="I am a scope label">
                    <em v-if="scope.errors && scope.errors.label" class="error-message">{{ scope.errors.label[0] }}</em>
                  </div>
                </div>
                <div class="five wide column">
                  <div class="ui checkbox">
                    <input type="checkbox" v-model="scope.public" placeholder="http://redirect.uri">
                    <label>Public</label>
                  </div>
                </div>
                <div class="three wide actions column">
                  <button v-on:click.prevent="viewScope(scope)" class="ui tiny blue button">cancel</button>
                  <button type="submit" class="ui tiny violet button">save</button>
                </div>
              </div>
            </form>
          </div>
          <div v-else>
            <div class="ui stackable grid">
              <div class="four wide column">
                <span class="ui teal label">{{ scope.name }}</span>
              </div>
              <div class="four wide column">
                <strong>{{ scope.label }}</strong>
              </div>
              <div class="five wide column">
                <div class="ui checkbox">
                  <input disabled type="checkbox" v-model="scope.public" placeholder="http://redirect.uri">
                  <label>Public</label>
                </div>
              </div>
              <div class="three wide actions column">
                <button v-on:click="editScope(scope)" class="ui tiny blue button">edit</button>
                <button v-on:click="deleteScope(scope)" class="ui tiny red button">delete</button>
              </div>
            </div>
          </div>
        </div>
      </div>
      <hr />
      <button @click="addScope()" class="ui violet add button">Add a scope</button>
    </div>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import Toaster from '../../components/Toaster.vue'

export default {
  name: 'client-list',
  components: {
    Toaster
  },
  data () {
    return {
      scopes: [],
      saved: false,
      deleted: false,
      errorMessage: false
    }
  },
  mounted () {
    this.getScopes()
  },
  methods: {
    getScopes () {
      Scope.all().then((scopes) => {
        this.scopes = scopes
      })
    },
    addScope () {
      this.scopes.push(new Scope({ edit: true }))
    },
    editScope (scope) {
      scope.edit = true
    },
    viewScope (scope) {
      if (scope.persisted) {
        scope.reset().then(() => {
          scope.edit = false
        })
      } else {
        this.deleteScope(scope)
      }
    },
    saveScope (scope) {
      this.saved = false
      this.errorMessage = false
      scope.save().then((scope) => {
        this.saved = true
        scope.edit = false
      }).catch((error) => {
        this.errorMessage = error.message
      })
    },
    deleteScope (scope) {
      if (!confirm('Are you sure ?')) return
      this.errorMessage = false
      this.deleted = false
      if (scope.persisted) {
        scope.destroy().then(() => {
          this.deleted = true
          this.scopes.splice(
            this.scopes.indexOf(scope),
            1
          )
        }).catch((error) => {
          this.errorMessage = error.message
        })
      } else {
        this.scopes.splice(
          this.scopes.indexOf(scope),
          1
        )
      }
    }
  }
}
</script>

<style scoped lang="scss">
#scope-list {
  .segments {
    border: none;
    @media screen and (max-width: 768px) {
      padding: 0 1rem;
    }
  }
  .ui.grid {
    margin-bottom: -1rem;
  }
  .column {
    padding: 1rem!important;
    display: flex;
    align-items: center;
    &.actions {
      margin: 0;
      justify-content: flex-end;
      .button {
        margin-left: 1em;
      }
    }
    .field {
      flex-direction: column;
      width: 100%;
      margin-bottom: 0;
      padding-bottom: 0;
      .error-message {
        color: #9f3a38;
      }
    }
  }
  .add.button {
    margin-bottom: 1rem;
    @media (max-width: 768px) {
      margin-left: 1rem;
    }
  }
}
</style>
