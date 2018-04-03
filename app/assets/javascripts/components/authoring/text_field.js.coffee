{div, span, h2} = React.DOM

modulejs.define 'components/authoring/text_field',
[
  'components/common/ajax_form_mixin'
],
(
  AjaxFormMixin
) ->

  TextField = React.createClass
    mixins:
      [AjaxFormMixin]

    currentText: ->
      @state.values[@props.propName] || @props.placeholder

    render: ->
      (div {className: "authoring-text-field #{if @state.edit then 'edit' else ''}"},
        if @state.edit
          (@text {name: @props.propName})
        else
          (span {}, @currentText())
        (span {className: 'text-field-links'},
          if @state.edit
            (span {},
              (span {onClick: @save}, 'Save')
              '|'
              (span {onClick: @cancel}, 'Cancel')
            )
          else
            (span {onClick: @edit}, 'Edit')
        )
      )
