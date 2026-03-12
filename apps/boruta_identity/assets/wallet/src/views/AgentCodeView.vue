<template>
  <div class="agent-code">
    <div class="ui container">
      <div class="ui large center aligned segment" v-if="!agentToken">
        <h1>Share a credential</h1>
        <p><pre>{{ content }}</pre></p>

        <div class="ui center aligned error message" v-if="error">
          {{ error }}
        </div>
        <button v-else class="ui fluid green button" @click="share()">Share</button>
      </div>
      <div class="ui center aligned segment" v-else>
        <a :href="preauthorizeUrl">{{ preauthorizeUrl }}</a>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent } from 'vue'
import axios from 'axios'

export default defineComponent({
  name: 'AgentCodeView',
  data () {
    const content = localStorage.getItem('shareContent')
    const code = new URL(window.location.href).searchParams.get('code')
    const bindData = JSON.stringify({ content })
    const bindConfiguration = '{}'
    return {
      error: null,
      agentToken: null,
      tokenUrl: window.env.BORUTA_OAUTH_BASE_URL + '/oauth/token',
      content,
      code,
      bindData,
      bindConfiguration,
      clientId: '00000000-0000-0000-0000-000000000001',
      clientSecret: '<client secret>',
      redirectUri: 'http://localhost:4000/accounts/wallet/agent-code'
    }
  },
  computed: {
    preauthorizeUrl () {
      return window.env.BORUTA_OAUTH_BASE_URL + `/oauth/authorize?client_id=00000000-0000-0000-0000-000000000001&redirect_uri=${window.env.BORUTA_OAUTH_BASE_URL}/accounts/wallet/preauthorized-code&response_type=urn%3Aietf%3Aparams%3Aoauth%3Aresponse-type%3Apre-authorized_code&state=qrm0c4xm&prompt=login&agent_token=${this.agentToken}`
    }
  },
  methods: {
    share () {
      axios.post(
        this.tokenUrl,
        {
          code: this.code,
          client_id: this.clientId,
          client_secret: this.clientSecret,
          redirect_uri: this.redirectUri,
          bind_data: this.bindData,
          bind_configuration: this.bindConfiguration,
          grant_type: 'agent_code'
        }
      ).then(({ data }) => {
        this.agentToken = data.agent_token
      }).catch(({ response }) => {
        this.error = response.data.error_description
      })
    }
  }
})
</script>

<style lang="scss">
</style>
