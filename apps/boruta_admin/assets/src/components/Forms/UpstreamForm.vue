<template>
  <div class="ui upstream-form segment">
    <FormErrors v-if="upstream.errors" :errors="upstream.errors" />
    <form class="ui form" @submit.prevent="submit">
      <div ref="tabularMenu" class="ui top attached stackable tabular menu">
        <a id="general-configuration" @click="openTab" class="active item">General configuration</a>
        <a id="uris" @click="openTab" class="item">URIs</a>
        <a id="authorization" @click="openTab" class="item">Authorization</a>
      </div>
      <div ref="form">
        <div ref="general-configuration" data-tab="general-configuration" class="ui bottom attached active tab segment">
          <h2>General configuration</h2>
          <div class="field" :class="{ 'error': upstream.errors?.node_name }">
            <label>Node</label>
            <select v-model="upstream.node_name" placeholder="global">
              <option value="global">global</option>
              <option v-for="name in nodeNames" :value="name">{{ name }}</option>
            </select>
          </div>
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
        </div>
        <div ref="uris" data-tab="uris" class="ui bottom attached tab segment">
          <h2>URIs</h2>
          <div class="upstreams field" :class="{ 'error': upstream.errors?.uris }">
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
        </div>
        <div ref="authorization" data-tab="authorization" class="ui bottom attached tab segment">
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
          <div v-if="isHsAlgorithm" class="field" :class="{ 'error': upstream.errors?.forwarded_token_secret }">
            <label>Forwarded token secret <em>(leave blank to autogenerate)</em></label>
            <input type="text" v-model="upstream.forwarded_token_secret" placeholder="text">
          </div>
          <div v-if="isRsAlgorithm">
            <div class="field" :class="{ 'error': upstream.errors?.forwarded_token_private_key }">
              <label>Forwarded token private key <em>(leave blank to autogenerate)</em></label>
              <textarea v-model="upstream.forwarded_token_private_key"></textarea>
            </div>
            <div class="field" :class="{ 'error': upstream.errors?.forwarded_token_public_key }">
              <label>Forwarded token public key</label>
              <textarea v-model="upstream.forwarded_token_public_key"></textarea>
            </div>
          </div>
        </div>
      </div>
      <div class="actions">
        <button class="ui right floated violet button" type="submit">{{ action }}</button>
      </div>
    </form>
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
      nodeNames: [],
      forwardedTokenSignatureAlgorithms: Upstream.forwardedTokenSignatureAlgorithms
    }
  },
  mounted () {
    Upstream.nodeList().then(nodes => this.nodeNames = nodes)
  },
  computed: {
    isHsAlgorithm () {
      return this.upstream.forwarded_token_signature_alg?.match(/HS/)
    },
    isRsAlgorithm () {
      return this.upstream.forwarded_token_signature_alg?.match(/RS/)
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
    },
    openTab (e) {
      const tab = e.target.id
      Array.from(this.$refs.tabularMenu.getElementsByClassName('item')).forEach(e => {
        if (e.id == tab) {
          e.classList.add('active')
          this.$refs[e.id].classList.add('active')
        } else {
          e.classList.remove('active')
          this.$refs[e.id].classList.remove('active')
        }
      })
    }
  },
  watch: {
    'upstream.errors': {
      deep: true,
      handler (errors) {
        setTimeout(() => {
          Array.from(this.$refs.tabularMenu.getElementsByClassName('error')).forEach(e => {
            e.classList.remove('error')
          })
          Array.from(this.$refs.form.getElementsByClassName('error')).forEach(elt => {
            const tab = elt.closest('.tab').getAttribute('data-tab')
            this.$refs.tabularMenu.querySelector('#' + tab).classList.add('error')
          })
        }, 100)
      }
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
