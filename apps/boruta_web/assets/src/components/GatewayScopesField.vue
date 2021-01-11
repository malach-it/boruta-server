<template>
  <div class="field edit-scopes">
    <div v-for="(authorizedScope, index) in currentScopes" class="field" :key="index">
      <div class="fields">
        <div class="four wide field">
          <label>Method</label>
          <input type="text" placeholder="GET" v-model="authorizedScope.method" />
        </div>
        <div class="twelve wide field">
          <label>Scope</label>
          <div class="ui right icon input">
            <select type="text" v-model="authorizedScope.model" class="authorized-scopes-select">
              <option :value="scope" v-for="scope in scopeOptions(authorizedScope.model)" :key="scope.id">{{ scope.name }}</option>
            </select>
            <i v-on:click="deleteScope(authorizedScope)" class="close icon"></i>
          </div>
        </div>
     </div>
    </div>
    <div class="ui info message" v-if="currentScopes.length"><i>You can use "*" as method wildcard</i></div>
    <button v-on:click.prevent="addScope()" class="ui blue fluid button">Add a scope</button>
  </div>
</template>

<script>
import Scope from '@/models/scope.model'

export default {
  name: 'ScopesField',
  props: {
    currentScopes: {
      type: Array,
      default: () => ([])
    }
  },
  data () {
    return {
      scopes: []
    }
  },
  computed: {
    scopeOptions () {
      const vm = this
      return function (authorizedScope) {
        return vm.scopes.map((scope) => {
          if (authorizedScope.name === scope.name) {
            return authorizedScope
          }
          return scope
        })
      }
    }
  },
  mounted () {
    Scope.all().then((scopes) => {
      this.scopes = scopes
    })
  },
  methods: {
    deleteScope (scope) {
      this.$emit('delete-scope', scope)
    },
    addScope () {
      this.$emit('add-scope')
    }
  }
}
</script>

<style scoped lang="scss">
</style>
