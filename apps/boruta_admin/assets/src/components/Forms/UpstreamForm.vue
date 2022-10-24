<template>
  <div class="upstream-form">
    <div class="ui segment">
      <FormErrors v-if="upstream.errors" :errors="upstream.errors" />
      <form class="ui form" @submit.prevent="submit">
        <h3>General configuration</h3>
        <div class="field" :class="{ 'error': upstream.errors?.scheme }">
          <label>Scheme</label>
          <select v-model="upstream.scheme" placeholder="https">
            <option value="https">https</option>
            <option value="http">http</option>
          </select>
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.host }">
          <label>Host</label>
          <input type="text" v-model="upstream.host" placeholder="host.test">
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.port }">
          <label>Port</label>
          <input type="text" v-model="upstream.port" placeholder="443">
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.pool_count }">
          <label>Pool count</label>
          <input type="number" v-model="upstream.pool_count" placeholder="10">
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.pool_size }">
          <label>Pool size</label>
          <input type="number" v-model="upstream.pool_size" placeholder="10">
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.max_idle_time }">
          <label>Max idle time</label>
          <input type="number" v-model="upstream.max_idle_time" placeholder="10">
        </div>
        <div class="upstreams field" :class="{ 'error': upstream.errors?.uris }">
          <label>URIs</label>
          <div v-for="(upstreamUri, index) in upstream.uris" class="field" :key="index">
            <div class="ui right icon input">
              <input type="text" v-model="upstreamUri.uri" placeholder="/matching (without trailing slash)" />
              <i v-on:click="deleteUpstreamUri(upstreamUri)" class="close icon"></i>
            </div>
          </div>
          <a v-on:click.prevent="addUpstreamUri()" class="ui blue fluid button">Add an upstream uri</a>
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
        <div class="field" v-if="upstream.authorize" :class="{ 'error': upstream.errors?.required_scopes }">
          <label>Required scopes <i>(leave empty to not filter)</i></label>
          <GatewayScopesField :currentScopes="upstream.required_scopes" @delete-scope="deleteScope" @add-scope="addScope" />
        </div>
        <div v-if="upstream.authorize">
          <h4>Error templates</h4>
          <div class="field" :class="{ 'error': upstream.errors?.error_content_type }">
            <label>Error content type</label>
            <input type="text" v-model="upstream.error_content_type" placeholder="text">
          </div>
          <div class="field" :class="{ 'error': upstream.errors?.forbidden_response }">
            <label>Forbidden response</label>
            <textarea v-model="upstream.forbidden_response" placeholder="You are forbidden to access this resource."></textarea>
          </div>
          <div class="field" :class="{ 'error': upstream.errors?.unauthorized_response }">
            <label>Unauthorized response</label>
            <textarea v-model="upstream.unauthorized_response" placeholder="You are unauthorized to access this resource."></textarea>
          </div>
        </div>
        <h3>Forwarded authorization</h3>
        <div class="ui segment">
          <div class="inline fields" :class="{ 'error': upstream.errors?.forwarded_token_signature_alg }">
            <label>Forwarded token signature algorithm</label>
            <div class="field" v-for="alg in forwardedTokenSignatureAlgorithms" :key="alg">
              <div class="ui radio checkbox">
                <label>{{ alg }}</label>
                <input type="radio" v-model="upstream.forwarded_token_signature_alg" :value="alg" />
              </div>
            </div>
          </div>
        </div>
        <div class="field" :class="{ 'error': upstream.errors?.error_content_type }">
          <label>Error content type</label>
          <input type="text" v-model="upstream.error_content_type" placeholder="text">
        </div>
        <hr />
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
        <a class="ui button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import Scope from '../../models/scope.model'
import Upstream from '../../models/upstream.model'
import GatewayScopesField from '../../components/Forms/GatewayScopesField.vue'
import FormErrors from '../../components/Forms/FormErrors.vue'

export default {
  name: 'upstream-form',
  props: ['upstream', 'action'],
  components: {
    FormErrors,
    GatewayScopesField
  },
  data () {
    return {
      forwardedTokenSignatureAlgorithms: Upstream.forwardedTokenSignatureAlgorithms
    }
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
