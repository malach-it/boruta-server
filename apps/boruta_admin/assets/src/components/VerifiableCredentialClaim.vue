<template>
  <div class="ui claim segment">
    <i class="ui large close icon" @click="deleteVerifiableCredentialClaim(credential, claim)"></i>
    <h5>Claim definition</h5>
    <div class="field" :class="{ 'error': errors?.verifiable_credentials }">
      <label>Type</label>
      <select v-model="claim.type">
        <optgroup label="attribute">
          <option :value="type" v-for="type in attributeClaimTypes">{{ type }}</option>
        </optgroup>
        <optgroup label="object">
          <option :value="type" v-for="type in objectClaimTypes">{{ type }}</option>
        </optgroup>
      </select>
    </div>
    <div v-if="isAttribute">
      <div class="field" :class="{ 'error': errors?.verifiable_credentials }">
        <label>Name</label>
        <input :disabled="claim.freeze" type="text" v-model="claim.name" placeholder="family_name">
      </div>
      <div class="field" :class="{ 'error': errors?.verifiable_credentials }">
        <label>Label</label>
        <input :disabled="claim.freeze" type="text" v-model="claim.label" placeholder="Family name">
      </div>
      <div class="field" :class="{ 'error': errors?.verifiable_credentials }">
        <label>Pointer</label>
        <input type="text" v-model="claim.pointer" placeholder="family_name">
      </div>
      <div class="field" v-if="format === 'vc+sd-jwt'" :class="{ 'error': errors?.verifiable_credentials }">
        <label>Expiration</label>
        <input type="text" v-model="claim.expiration" placeholder="3784320000">
      </div>
    </div>
    <div v-if="isObject">
      <div class="field" :class="{ 'error': errors?.verifiable_credentials }">
        <label>Name</label>
        <input :disabled="claim.freeze" type="text" v-model="claim.name" placeholder="family_name">
      </div>
      <div class="field">
        <h5>Subclaims</h5>
        <div v-for="childClaim in claim.claims">
          <VerifiableCredentialClaim :format="format" :credential="claim" :claim="childClaim" :errors="errors"></VerifiableCredentialClaim>
        </div>
        <div class="field">
          <a class="ui blue fluid button" @click="addChildClaim(claim)">Add a claim</a>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { Claim } from '../models/backend.model'

export default {
  name: 'verifiable-credential-claim',
  props: ['credential', 'claim', 'errors', 'format'],
  data () {
    return {
      attributeClaimTypes: Claim.attributeTypes,
      objectClaimTypes: Claim.objectTypes
    }
  },
  computed: {
    isAttribute () {
      return this.claim.isAttribute
    },
    isObject () {
      return this.claim.isObject
    }
  },
  methods: {
    deleteVerifiableCredentialClaim (credential, claim) {
      credential.claims.splice(
        credential.claims.indexOf(claim),
        1
      )
    },
    addChildClaim(claim) {
      claim.claims.push(
        Claim.build('attribute')
      )
    }
  },
  watch: {
    'claim.type': function (claimType) {
      this.claim.assignType(claimType)
    }
  }
}
</script>

<style lang="scss" scoped>
.claim.segment {
  .field {
    margin-bottom: 1em!important;
  }
  .close.icon {
    position: absolute;
    cursor: pointer;
    top: 1.17em;
    right: .5em;
  }
}
</style>
