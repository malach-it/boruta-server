<template>
  <div class="field edit-scopes">
    <div v-for="(authorizedScope, index) in currentScopes" class="field" :key="index">
      <div class="ui right icon input">
        <select type="text" v-model="authorizedScope.model" class="authorized-scopes-select">
          <option :value="scope" v-for="scope in scopeOptions(authorizedScope.model)" :key="scope.id">{{ scope.name }}</option>
        </select>
        <i v-on:click="deleteScope(authorizedScope)" class="close icon"></i>
      </div>
    </div>
    <a v-on:click.prevent="addScope()" class="ui blue fluid button">Add a scope</a>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'

export default {
  name: 'ScopesField',
  props: ['currentScopes'],
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

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped lang="scss">
.edit-scopes {
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
