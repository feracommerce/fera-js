require 'spec_helper'

describe "Home - Index", type: :feature, js: true do
  scenario "visit home page without anything connected" do
    visit "/index.html"
    expect(page).to have_selector('body')
  end
end
