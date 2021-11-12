<template>
  <div class="edit-upstream">
    <div class="main header">
      <h1>Edit Upstream</h1>
    </div>
    <div class="ui container">
      <div class="ui large segment">
        <FormErrors v-if="errors" :errors="errors" />
        <form class="ui form" v-on:submit.prevent="updateUpstream()">
          <div class="ui large segment">
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
            <div class="upstreams field">
              <label>URIs</label>
              <div v-for="(upstreamUri, index) in upstream.uris" class="field" :key="index">
                <div class="ui right icon input">
                  <input type="text" v-model="upstreamUri.uri" placeholder="/matching" />
                  <i v-on:click="deleteUpstreamUri(upstreamUri)" class="close icon"></i>
                </div>
              </div>
              <button v-on:click.prevent="addUpstreamUri()" class="ui blue fluid button">Add a redirect uri</button>
            </div>
            <div class="field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="upstream.strip_uri">
                <label>Strip URI</label>
              </div>
            </div>
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
          </div>
          <button class="ui big violet button" type="submit">Update</button>
          <router-link :to="{ name: 'upstream-list' }" class="ui button">Back</router-link>
        </form>
      </div>
    </div>
  </div>
</template>

<script>
import Upstream from '@/models/upstream.model'
import Scope from '@/models/scope.model'
import GatewayScopesField from '@/components/GatewayScopesField.vue'
import FormErrors from '@/components/FormErrors.vue'

export default {
  name: 'upstreams',
  components: {
    FormErrors,
    GatewayScopesField
  },
  mounted () {
    const { upstreamId } = this.$route.params
    Upstream.get(upstreamId).then((upstream) => {
      this.upstream = upstream
    })
  },
  data () {
    return {
      errors: null,
      upstream: new Upstream()
    }
  },
  methods: {
    updateUpstream () {
      this.errors = null

      return this.upstream.save().then(() => {
        this.$router.push({ name: 'upstream-list' })
      }).catch((errors) => {
        this.errors = errors
      })
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
.edit-upstream {
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
