# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Security: Nav Menus Mass Assignment', type: :request do
  let(:site) { create(:site) }
  let(:admin) { create(:user_admin, site: nil) }

  before do
    CamaleonCms::Site.delete_all
    site
    post cama_admin_login_path, params: { user: { username: admin.username, password: '12345678' } }
  end

  describe 'POST create nav menu' do
    it 'only permits name and slug, rejecting other attributes' do
      expect do
        post cama_admin_appearances_nav_menus_path,
             params: {
               nav_menu: {
                 name: 'Test Menu',
                 slug: 'test-menu',
                 taxonomy: 'post_tag',
                 parent_id: 99_999,
                 user_id: 99_999
               }
             }
      end.to change(CamaleonCms::NavMenu, :count).by(1)

      nav_menu = CamaleonCms::NavMenu.last
      expect(nav_menu.name).to eq('Test Menu')
      expect(nav_menu.slug).to eq('test-menu')
      expect(nav_menu.taxonomy).to eq('nav_menu')
      expect(nav_menu.parent_id).to eq(site.id)
    end
  end

  describe 'PATCH update nav menu' do
    let!(:nav_menu) { site.nav_menus.create!(name: 'Original', slug: 'original') }

    it 'only permits name and slug, rejecting other attributes' do
      patch cama_admin_appearances_nav_menu_path(nav_menu),
            params: {
              nav_menu: {
                name: 'Updated Menu',
                slug: 'updated-menu',
                taxonomy: 'post_tag',
                parent_id: 99_999
              }
            }

      expect(response.status).to eq(302)
      nav_menu.reload
      expect(nav_menu.name).to eq('Updated Menu')
      expect(nav_menu.slug).to eq('updated-menu')
      expect(nav_menu.taxonomy).to eq('nav_menu')
      expect(nav_menu.parent_id).to eq(site.id)
    end
  end
end
