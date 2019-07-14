<template>
  <div id="scope-list">
    <div class="ui container">
      <h1>Scopes</h1>
      <div class="ui segments">
        <div v-for="(scope, index) in scopes" class="ui mini segment" :key="index">
          <div v-if="scope.edit">
            <form v-on:submit.prevent="saveScope(scope)" class="ui form">
              <div class="ui grid">
                <div class="eight wide column">
                  <div class="ui mini input" :class="{ 'error': scope.errors && scope.errors.name }">
                    <input type="text" v-model="scope.name" placeholder="iam:a:scope">
                    <em v-if="scope.errors && scope.errors.name" class="error-message">{{ scope.errors.name[0] }}</em>
                  </div>
                </div>
                <div class="five wide column">
                  <div class="ui toggle checkbox">
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
            <div class="ui grid">
              <div class="eight wide column">
                <div class="ui mini input">
                  {{ scope.name }}
                </div>
              </div>
              <div class="five wide column">
                <div class="ui toggle checkbox">
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
      <div class="actions">
        <button @click="addScope()" class="ui blue big button">Add a scope</button>
      </div>
    </div>
  </div>
</template>

<script>
import Scope from '@/models/scope.model'
export default {
  name: 'client-list',
  beforeRouteEnter (to, from, next) {
    next(vm => {
      if (!vm.$auth.isAuthenticated()) {
        vm.$router.push({ name: 'home' })
      }
    })
  },
  data () {
    return { scopes: [], errors: null }
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
      this.errors = null
      scope.save().then((scope) => {
        scope.edit = false
      })
    },
    deleteScope (scope) {
      if (!confirm('Are you sure ?')) return
      if (scope.persisted) {
        scope.destroy().then(() => {
          this.scopes.splice(
            this.scopes.indexOf(scope),
            1
          )
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
  .column {
    display: flex;
    align-items: center;
    &.actions {
      margin: 0;
      justify-content: flex-end;
      .button {
        margin-left: 1em;
      }
    }
    .input {
      flex-direction: column;
      width: 100%;
      .error-message {
        color: #9f3a38;
      }
    }
  }
}
</style>
