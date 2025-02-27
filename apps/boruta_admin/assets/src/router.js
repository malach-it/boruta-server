import { createWebHistory, createRouter } from "vue-router";
import oauth from "./services/oauth.service";

import Main from "./views/Layouts/Main.vue";

import Home from "./views/Home.vue";

import OauthCallback from "./views/OauthCallback.vue";
import NotFound from "./views/NotFound.vue";
import BadRequest from "./views/BadRequest.vue";

import Clients from "./views/Clients.vue";
import ClientList from "./views/Clients/ClientList.vue";
import KeyPairList from "./views/Clients/KeyPairList.vue";
import NewClient from "./views/Clients/NewClient.vue";
import Client from "./views/Clients/Client.vue";
import EditClient from "./views/Clients/EditClient.vue";

import Upstreams from "./views/Upstreams.vue";
import UpstreamList from "./views/Upstreams/UpstreamList.vue";
import Upstream from "./views/Upstreams/Upstream.vue";
import NewUpstream from "./views/Upstreams/NewUpstream.vue";
import EditUpstream from "./views/Upstreams/EditUpstream.vue";

import IdentityProviders from "./views/IdentityProviders.vue";
import IdentityProviderList from "./views/IdentityProviders/IdentityProviderList.vue";
import IdentityProvider from "./views/IdentityProviders/IdentityProvider.vue";
import EditIdentityProvider from "./views/IdentityProviders/EditIdentityProvider.vue";
import EditLayoutTemplate from "./views/IdentityProviders/EditLayoutTemplate.vue";
import EditSessionTemplate from "./views/IdentityProviders/EditSessionTemplate.vue";
import EditNewChooseSessionTemplate from "./views/IdentityProviders/EditNewChooseSessionTemplate.vue";
import EditTotpRegistrationTemplate from "./views/IdentityProviders/EditTotpRegistrationTemplate.vue";
import EditTotpAuthenticationTemplate from "./views/IdentityProviders/EditTotpAuthenticationTemplate.vue";
import EditWebauthnAuthenticationTemplate from "./views/IdentityProviders/EditWebauthnAuthenticationTemplate.vue";
import EditWebauthnRegistrationTemplate from "./views/IdentityProviders/EditWebauthnRegistrationTemplate.vue";
import EditRegistrationTemplate from "./views/IdentityProviders/EditRegistrationTemplate.vue";
import EditNewConsentTemplate from "./views/IdentityProviders/EditNewConsentTemplate.vue";
import EditNewConfirmationTemplate from "./views/IdentityProviders/EditNewConfirmationTemplate.vue";
import EditNewResetPasswordTemplate from "./views/IdentityProviders/EditNewResetPasswordTemplate.vue";
import EditEditResetPasswordTemplate from "./views/IdentityProviders/EditEditResetPasswordTemplate.vue";
import EditEditUserTemplate from "./views/IdentityProviders/EditEditUserTemplate.vue";
import EditCredentialOfferTemplate from "./views/IdentityProviders/EditCredentialOfferTemplate.vue";
import EditCrossDevicePresentationTemplate from "./views/IdentityProviders/EditCrossDevicePresentationTemplate.vue";
import NewIdentityProvider from "./views/IdentityProviders/NewIdentityProvider.vue";

import Users from "./views/IdentityProviders/Users.vue";
import UserList from "./views/IdentityProviders/UserList.vue";
import UserImport from "./views/IdentityProviders/UserImport.vue";
import NewUser from "./views/IdentityProviders/NewUser.vue";
import EditUser from "./views/IdentityProviders/EditUser.vue";

import Organizations from "./views/IdentityProviders/Organizations.vue";
import OrganizationList from "./views/IdentityProviders/OrganizationList.vue";
import NewOrganization from "./views/IdentityProviders/NewOrganization.vue";
import EditOrganization from "./views/IdentityProviders/EditOrganization.vue";

import Backends from "./views/IdentityProviders/Backends.vue";
import Backend from "./views/IdentityProviders/Backends/Backend.vue";
import BackendList from "./views/IdentityProviders/BackendList.vue";
import NewBackend from "./views/IdentityProviders/NewBackend.vue";
import EditBackend from "./views/IdentityProviders/EditBackend.vue";
import EditConfirmationInstructionsEmailTemplate from "./views/IdentityProviders/Backends/EditConfirmationInstructionsEmailTemplate.vue";
import EditResetPasswordInstructionsEmailTemplate from "./views/IdentityProviders/Backends/EditResetPasswordInstructionsEmailTemplate.vue";
import EditTxCodeEmailTemplate from "./views/IdentityProviders/Backends/EditTxCodeEmailTemplate.vue";

import Scopes from "./views/Scopes.vue";
import ScopeList from "./views/Scopes/ScopeList.vue";

import Roles from "./views/Roles.vue";
import RoleList from "./views/Roles/RoleList.vue";
import Role from "./views/Roles/Role.vue";
import NewRole from "./views/Roles/NewRole.vue";
import EditRole from "./views/Roles/EditRole.vue";

import Configuration from "./views/Configuration.vue";
import ConfigurationFileUpload from "./views/Configuration/ConfigurationFileUpload.vue";
import ErrorTemplateList from "./views/Configuration/ErrorTemplateList.vue";
import EditBadRequestTemplate from "./views/Configuration/EditBadRequestTemplate.vue";
import EditNotFoundTemplate from "./views/Configuration/EditNotFoundTemplate.vue";
import EditForbiddenTemplate from "./views/Configuration/EditForbiddenTemplate.vue";
import EditInternalServerErrorTemplate from "./views/Configuration/EditInternalServerErrorTemplate.vue";

import Dashboard from "./views/Dashboard.vue";
import Requests from "./views/Dashboard/Requests.vue";
import BusinessEvents from "./views/Dashboard/BusinessEvents.vue";

const router = createRouter({
  history: createWebHistory(),
  linkActiveClass: "active",
  routes: [
    {
      path: "/",
      component: Main,
      name: "root",
      redirect: "/",
      children: [
        {
          path: "",
          name: "home",
          component: Home,
        },
        {
          path: "not-found",
          name: "not-found",
          component: NotFound,
        },
        {
          path: "bad-request",
          name: "bad-request",
          component: BadRequest,
        },
        {
          path: "/oauth-callback",
          name: "oauth-callback",
          component: OauthCallback,
        },
        {
          path: "/dashboard",
          name: "dashboard",
          component: Dashboard,
          redirect: "/dashboard/requests",
          children: [
            {
              path: "requests",
              name: "request-logs",
              component: Requests,
            },
            {
              path: "business-events",
              name: "business-event-logs",
              component: BusinessEvents,
            },
          ],
        },
        {
          path: "/identity-providers",
          component: IdentityProviders,
          name: "identity-providers",
          redirect: "/identity-providers/",
          children: [
            {
              path: "",
              name: "identity-provider-list",
              component: IdentityProviderList,
            },
            {
              path: "new",
              name: "new-identity-provider",
              component: NewIdentityProvider,
            },
            {
              path: "/identity-providers/:identityProviderId",
              name: "identity-provider",
              component: IdentityProvider,
              redirect: (to) => ({
                name: "edit-identity-provider",
                params: { identityProviderId: to.params.identityProviderId },
              }),
              children: [
                {
                  path: "edit",
                  name: "edit-identity-provider",
                  component: EditIdentityProvider,
                },
                {
                  path: "edit/choose-session-template",
                  name: "edit-choose-session-template",
                  component: EditNewChooseSessionTemplate,
                },
                {
                  path: "edit/layout-template",
                  name: "edit-layout-template",
                  component: EditLayoutTemplate,
                },
                {
                  path: "edit/session-template",
                  name: "edit-session-template",
                  component: EditSessionTemplate,
                },
                {
                  path: "edit/totp-registration-template",
                  name: "edit-totp-registration-template",
                  component: EditTotpRegistrationTemplate,
                },
                {
                  path: "edit/totp-authentication-template",
                  name: "edit-totp-authentication-template",
                  component: EditTotpAuthenticationTemplate,
                },
                {
                  path: "edit/webauthn-registration-template",
                  name: "edit-webauthn-registration-template",
                  component: EditWebauthnRegistrationTemplate,
                },
                {
                  path: "edit/webauthn-authentication-template",
                  name: "edit-webauthn-authentication-template",
                  component: EditWebauthnAuthenticationTemplate,
                },
                {
                  path: "edit/registration-template",
                  name: "edit-registration-template",
                  component: EditRegistrationTemplate,
                },
                {
                  path: "edit/edit-user-template",
                  name: "edit-edit-user-template",
                  component: EditEditUserTemplate,
                },
                {
                  path: "edit/send-reset-password-instructions-template",
                  name: "edit-new-reset-password-template",
                  component: EditNewResetPasswordTemplate,
                },
                {
                  path: "edit/reset-password-template",
                  name: "edit-edit-reset-password-template",
                  component: EditEditResetPasswordTemplate,
                },
                {
                  path: "edit/consent-template",
                  name: "edit-new-consent-template",
                  component: EditNewConsentTemplate,
                },
                {
                  path: "edit/send-confirmation-instructions-template",
                  name: "edit-new-confirmation-template",
                  component: EditNewConfirmationTemplate,
                },
                {
                  path: "edit/credential-offer-template",
                  name: "edit-credential-offer-template",
                  component: EditCredentialOfferTemplate,
                },
                {
                  path: "edit/cross-device-presentation-template",
                  name: "edit-cross-device-presentation-template",
                  component: EditCrossDevicePresentationTemplate,
                },
              ],
            },
            {
              path: "backends",
              name: "backends",
              component: Backends,
              redirect: "/identity-providers/backends/",
              children: [
                {
                  path: "",
                  name: "backend-list",
                  component: BackendList,
                },
                {
                  path: "/backends/new",
                  name: "new-backend",
                  component: NewBackend,
                },
                {
                  path: "/backends/:backendId",
                  name: "backend",
                  component: Backend,
                  redirect: (to) => ({
                    name: "edit-backend",
                    params: { backendId: to.params.backendId },
                  }),
                  children: [
                    {
                      path: "edit",
                      name: "edit-backend",
                      component: EditBackend,
                    },
                    {
                      path: "edit/confirmation-instructions-email-template",
                      name: "edit-confirmation-instructions-email-template",
                      component: EditConfirmationInstructionsEmailTemplate,
                    },
                    {
                      path: "edit/reset-password-instructions-email-template",
                      name: "edit-reset-password-instructions-email-template",
                      component: EditResetPasswordInstructionsEmailTemplate,
                    },
                    {
                      path: "edit/tx-code-email-template",
                      name: "edit-tx-code-email-template",
                      component: EditTxCodeEmailTemplate,
                    },
                  ],
                },
              ],
            },
            {
              path: "users",
              name: "users",
              component: Users,
              redirect: "/identity-providers/users/",
              children: [
                {
                  path: "",
                  name: "user-list",
                  component: UserList,
                },
                {
                  path: "import",
                  name: "user-import",
                  component: UserImport,
                },
                {
                  path: "/users/new",
                  name: "new-user",
                  component: NewUser,
                },
                {
                  path: "/users/:userId/edit",
                  name: "edit-user",
                  component: EditUser,
                },
              ],
            },
            {
              path: "organizations",
              name: "organizations",
              component: Organizations,
              redirect: "/identity-providers/organizations/",
              children: [
                {
                  path: "",
                  name: "organization-list",
                  component: OrganizationList,
                },
                {
                  path: "/organizations/new",
                  name: "new-organization",
                  component: NewOrganization,
                },
                {
                  path: "/organizations/:organizationId/edit",
                  name: "edit-organization",
                  component: EditOrganization,
                },
              ],
            },
          ],
        },
        {
          path: "/clients",
          component: Clients,
          name: "clients",
          redirect: "/clients/",
          children: [
            {
              path: "",
              name: "client-list",
              component: ClientList,
            },
            {
              path: "key-pairs",
              name: "key-pair-list",
              component: KeyPairList,
            },
            {
              path: "/clients/new",
              name: "new-client",
              component: NewClient,
            },
            {
              path: "/clients/:clientId",
              name: "client",
              component: Client,
              redirect: (to) => ({
                name: "edit-client",
                params: { clientId: to.params.clientId },
              }),
              children: [
                {
                  path: "edit",
                  name: "edit-client",
                  component: EditClient,
                },
              ],
            },
          ],
        },
        {
          path: "/upstreams",
          component: Upstreams,
          name: "upstreams",
          redirect: "/upstreams/",
          children: [
            {
              path: "",
              name: "upstream-list",
              component: UpstreamList,
            },
            {
              path: "/upstreams/new",
              name: "new-upstream",
              component: NewUpstream,
            },
            {
              path: "/upstreams/:upstreamId",
              name: "upstream",
              component: Upstream,
              redirect: (to) => ({
                name: "edit-upstream",
                params: { upstreamId: to.params.upstreamId },
              }),
              children: [
                {
                  path: "edit",
                  name: "edit-upstream",
                  component: EditUpstream,
                },
              ],
            },
          ],
        },
        {
          path: "/scopes",
          component: Scopes,
          name: "scopes",
          redirect: "/scopes/",
          children: [
            {
              path: "",
              name: "scope-list",
              component: ScopeList,
            },
            {
              path: "/roles",
              component: Roles,
              name: "roles",
              redirect: "/roles/",
              children: [
                {
                  path: "",
                  name: "role-list",
                  component: RoleList,
                },
                {
                  path: "/roles/new",
                  name: "new-role",
                  component: NewRole,
                },
                {
                  path: "/roles/:roleId",
                  name: "role",
                  component: Role,
                  redirect: (to) => ({
                    name: "edit-role",
                    params: { roleId: to.params.roleId },
                  }),
                  children: [
                    {
                      path: "edit",
                      name: "edit-role",
                      component: EditRole,
                    },
                  ],
                },
              ],
            },
          ],
        }, {
          path: "/configuration",
          component: Configuration,
          name: "configuration",
          redirect: "/configuration/error-template-list",
          children: [
            {
              path: "",
              name: "",
              component: Configuration,
            },
            {
              path: "configuration-file-upload/:type(example-configuration-file)?",
              name: "configuration-file-upload",
              component: ConfigurationFileUpload,
            },
            {
              path: "error-template-list",
              name: "error-template-list",
              component: ErrorTemplateList,
            },
            {
              path: "edit-bad-request-template",
              name: "edit-bad-request-template",
              component: EditBadRequestTemplate,
            },
            {
              path: "edit-forbidden-template",
              name: "edit-forbidden-template",
              component: EditForbiddenTemplate,
            },
            {
              path: "edit-not-found-template",
              name: "edit-not-found-template",
              component: EditNotFoundTemplate,
            },
            {
              path: "edit-internal-server-error-template",
              name: "edit-internal-server-error-template",
              component: EditInternalServerErrorTemplate,
            },
          ],
        },
        {
          path: "/:pathMatch(.*)*",
          name: "not-found",
          component: NotFound,
        },
      ],
    },
  ],
});

router.beforeEach((to, _from, next) => {
  if (to.name === "oauth-callback") return next();

  oauth.storeLocationName(to);

  if (!oauth.isAuthenticated) {
    // TODO find a way to remove event listener once triggered
    const continueNavigation = () => {
      router.push(oauth.storedLocation);
      window.removeEventListener("logged_in", continueNavigation);
    };
    window.addEventListener("logged_in", continueNavigation);

    oauth.silentRefresh();
    return next(new Error('Not logged in'));
  } else {
    return next();
  }
});

export default router;
