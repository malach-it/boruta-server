<template>
  <div class="upstream-form">
    <div class="ui large segment">
      <FormErrors v-if="upstream.errors" :errors="upstream.errors" />
      <form class="ui form" @submit.prevent="submit">
        <h3>General configuration</h3>
        <div class="field">
          <label>Scheme</label>
          <select v-model="upstream.scheme" placeholder="https">
            <option value="https">https</option>
            <option value="http">http</option>
          </select>
        </div>
        <div class="field">
          <label>Host</label>
          <input type="text" v-model="upstream.host" placeholder="host.test">
        </div>
        <div class="field">
          <label>Port</label>
          <input type="text" v-model="upstream.port" placeholder="443">
        </div>
        <div class="field">
          <label>Pool size</label>
          <input type="number" v-model="upstream.pool_size" placeholder="10">
        </div>
        <div class="upstreams field">
          <label>URIs</label>
          <div v-for="(upstreamUri, index) in upstream.uris" class="field" :key="index">
            <div class="ui right icon input">
              <input type="text" v-model="upstreamUri.uri" placeholder="/matching" />
              <i v-on:click="deleteUpstreamUri(upstreamUri)" class="close icon"></i>
            </div>
          </div>
          <button v-on:click.prevent="addUpstreamUri()" class="ui blue fluid button">Add an upstream uri</button>
        </div>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="upstream.strip_uri">
            <label>Strip URI</label>
          </div>
        </div>
        <h3>Authorization</h3>
        <div class="field">
          <div class="ui toggle checkbox">
            <input type="checkbox" v-model="upstream.authorize">
            <label>Authorize</label>
          </div>
        </div>
        <div class="field" v-if="upstream.authorize">
          <label>Required scopes <i>(leave empty to not filter)</i></label>
          <GatewayScopesField :currentScopes="upstream.required_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
        </div>
        <hr />
        <button class="ui large right floated violet button" type="submit">{{ action }}</button>
        <a class="ui large button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import GatewayScopesField from '../../components/Forms/GatewayScopesField.vue'
import FormErrors from '../../components/Forms/FormErrors.vue'

export default {
  name: 'upstream-form',
  props: ['upstream', 'action'],
  components: {
    FormErrors,
    GatewayScopesField
  },
  methods: {
    back () {
      this.$emit('back')
    },
    addUpstreamUri () {
      this.upstream.uris.push({})
    },
    deleteUpstreamUri (uri) {
      this.upstream.uris.splice(
        this.upstream.uris.indexOf(uri),
        1
      )
    },
    addScope () {
      this.upstream.required_scopes.push({ model: new Scope(), method: 'GET' })
    },
    deleteScope (scope) {
      this.upstream.required_scopes.splice(
        this.upstream.required_scopes.indexOf(scope),
        1
      )
    }
  }
}
</script>

<style scoped lang="scss">
.upstream-form {
  .field {
    position: relative;
    &.upstreams input {
      margin-right: 3em;
    }
  }
  .ui.icon.input>i.icon.close {
    cursor: pointer;
    pointer-events: all;
    position: absolute;
  }
  .authorized-scopes-select {
    margin-right: 3em;
  }
}
</style>
