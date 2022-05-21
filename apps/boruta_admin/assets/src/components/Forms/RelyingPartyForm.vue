<template>
  <div class="relying-party-form">
    <div class="ui large segment">
      <FormErrors v-if="relyingParty.errors" :errors="relyingParty.errors" />
      <form class="ui form" @submit.prevent="submit">
        <section>
          <h3>General configuration</h3>
          <div class="field">
            <label>Name</label>
            <input type="text" v-model="relyingParty.name" placeholder="Super relying party">
          </div>
          <div class="field">
            <label>Type</label>
            <select v-model="relyingParty.type">
              <option value="internal">internal</option>
            </select>
          </div>
          <div v-if="relyingParty.isPersisted" class="ui segment">
            <router-link
              :to="{ name: 'edit-layout-template', params: { relyingPartyId: relyingParty.id } }"
              class="ui fluid blue button">Edit layout template</router-link>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>Sessions</h3>
          <div class="ui segment">
            <router-link
              :to="{ name: 'edit-session-template', params: { relyingPartyId: relyingParty.id } }"
              class="ui fluid blue button">Edit login template</router-link>
          </div>
          <div class="ui segment">
            <router-link
              :to="{ name: 'edit-new-reset-password-template', params: { relyingPartyId: relyingParty.id } }"
              class="ui fluid blue button">Edit send reset password instructions template</router-link>
          </div>
          <div class="ui segment">
            <router-link
              :to="{ name: 'edit-edit-reset-password-template', params: { relyingPartyId: relyingParty.id } }"
              class="ui fluid blue button">Edit reset password template</router-link>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>Choose session</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="relyingParty.choose_session">
              <label>choose session</label>
            </div>
            <p class="ui info message">
              Give the ability for the user to choose to keep current session or to create a new one on authorization
            </p>
            <div v-if="relyingParty.choose_session">
              <router-link
                :to="{ name: 'edit-choose-session-template', params: { relyingPartyId: relyingParty.id } }"
                class="ui fluid blue button">Edit choose session template</router-link>
            </div>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>Registration</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="relyingParty.registrable">
              <label>registrable</label>
            </div>
            <p class="ui info message">
              Give the ability for end users to register within the given relying party. If activated the user have access to registration page and can provide its own credentials.
            </p>
            <div v-if="relyingParty.registrable">
              <router-link
                :to="{ name: 'edit-registration-template', params: { relyingPartyId: relyingParty.id } }"
                class="ui fluid blue button">Edit registration template</router-link>
            </div>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>User information edition</h3>
          <div class="ui segment">
            <div class="ui toggle checkbox">
              <input type="checkbox" v-model="relyingParty.user_editable">
              <label>user editable</label>
            </div>
            <p class="ui info message">
              Give the ability for end users to update their account information.
            </p>
            <div v-if="relyingParty.user_editable">
              <router-link
                :to="{ name: 'edit-edit-user-template', params: { relyingPartyId: relyingParty.id } }"
                class="ui fluid blue button">Edit user edition template</router-link>
            </div>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>Email confirmation</h3>
          <div class="ui segment">
            <div class=" field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="relyingParty.confirmable">
                <label>confirmable</label>
              </div>
              <p class="ui info message">
                Confirm new registred accounts. sends an email in order to confirm user's email.
              </p>
              <div v-if="relyingParty.confirmable">
                <router-link
                  :to="{ name: 'edit-new-confirmation-template', params: { relyingPartyId: relyingParty.id } }"
                  class="ui fluid blue button">Edit send confirmation template</router-link>
              </div>
            </div>
          </div>
        </section>
        <section v-if="relyingParty.isPersisted">
          <h3>User consent</h3>
          <div class="ui segment">
            <div class=" field">
              <div class="ui toggle checkbox">
                <input type="checkbox" v-model="relyingParty.consentable">
                <label>user consent</label>
              </div>
              <p class="ui info message">
                Users have to consent requested scopes to be authorized.
              </p>
              <div v-if="relyingParty.consentable">
                <router-link
                  :to="{ name: 'edit-new-consent-template', params: { relyingPartyId: relyingParty.id } }"
                  class="ui fluid blue button">Edit consent template</router-link>
              </div>
            </div>
          </div>
        </section>
        <hr />
        <button class="ui large right floated violet button" type="submit">{{ action }}</button>
        <a class="ui large button" v-on:click="back()">Back</a>
      </form>
    </div>
  </div>
</template>

<script>
import FormErrors from './FormErrors.vue'

export default {
  name: 'relying-party-form',
  props: ['relyingParty', 'action'],
  components: {
    FormErrors
  },
  methods: {
    back () {
      this.$emit('back')
    }
  }
}
</script>

<style scoped lang="scss">
.relying-party-form {
  section {
    margin-bottom: 1rem;
  }
}
</style>
