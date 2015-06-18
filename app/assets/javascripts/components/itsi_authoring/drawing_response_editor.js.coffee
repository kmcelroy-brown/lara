{div, label, img} = React.DOM

modulejs.define 'components/itsi_authoring/drawing_response_editor',
[
  'components/itsi_authoring/section_element_editor_mixin',
  'components/itsi_authoring/section_editor_form',
  'components/itsi_authoring/section_editor_element'
],
(
  SectionElementEditorMixin,
  SectionEditorFormClass,
  SectionEditorElementClass
) ->

  SectionEditorForm = React.createFactory SectionEditorFormClass
  SectionEditorElement = React.createFactory SectionEditorElementClass

  React.createClass

    mixins:
      [SectionElementEditorMixin]

    # maps form names to @props.data keys
    dataMap:
      'embeddable_image_question[bg_url]': 'bg_url'

    initialEditState: ->
      false

    render: ->
      (SectionEditorElement {data: @props.data, title: 'Drawing Response', toHide: 'embeddable_image_question[is_hidden]', onEdit: @edit, alert: @props.alert},
        if @state.edit
          (SectionEditorForm {onSave: @save, onCancel: @cancel},
            (label {}, 'Background Image')
            (@text {name: 'embeddable_image_question[bg_url]'})
          )
        else
          (div {className: 'ia-section-text'},
            if @state.values['embeddable_image_question[bg_url]']
              (img {src: @state.values['embeddable_image_question[bg_url]']})
            else
              (div {className: 'ia-section-default-drawing-tool'})
          )
      )
