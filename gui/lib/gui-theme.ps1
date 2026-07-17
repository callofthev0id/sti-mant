# gui/lib/gui-theme.ps1 - ResourceDictionary WPF con la paleta y estilos de la app.
# Paleta propia (ver branding/design-system.md). Cambiar un color = editar una linea aca.
function New-AppTheme {
@'
<Window.Resources>
  <SolidColorBrush x:Key="AppAccent"      Color="#5EAE87"/>
  <SolidColorBrush x:Key="AppAccentDeep"  Color="#0E271B"/>
  <SolidColorBrush x:Key="AppAccentClaro" Color="#77BC9A"/>
  <SolidColorBrush x:Key="AppBody"       Color="#0D1411"/>
  <SolidColorBrush x:Key="AppWindow"     Color="#101814"/>
  <SolidColorBrush x:Key="AppCard"       Color="#16211C"/>
  <SolidColorBrush x:Key="AppChipBg"     Color="#182E23"/>
  <SolidColorBrush x:Key="AppChipBar"    Color="#11241B"/>
  <SolidColorBrush x:Key="AppInput"      Color="#0F1914"/>
  <SolidColorBrush x:Key="AppBorde"      Color="#30433A"/>
  <SolidColorBrush x:Key="AppBordeSutil" Color="#24372E"/>
  <SolidColorBrush x:Key="AppTexto"      Color="#ECF0EE"/>
  <SolidColorBrush x:Key="AppTexto2"     Color="#A4BBB0"/>
  <SolidColorBrush x:Key="AppTexto3"     Color="#8BAC9C"/>
  <SolidColorBrush x:Key="AppTenue"      Color="#7DA792"/>
  <SolidColorBrush x:Key="AppAmbar"      Color="#C79C53"/>
  <SolidColorBrush x:Key="AppNaranja"    Color="#C77539"/>
  <SolidColorBrush x:Key="AppRojo"       Color="#DA6A72"/>
  <SolidColorBrush x:Key="AppNa"         Color="#71837A"/>

  <Style x:Key="AppLabel" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource AppTexto3}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="10"/>
    <Setter Property="FontWeight" Value="600"/>
  </Style>

  <Style x:Key="AppSecHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource AppTenue}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="Margin" Value="0,12,0,6"/>
  </Style>

  <Style x:Key="AppGrupoHeader" TargetType="TextBlock">
    <Setter Property="Foreground" Value="{StaticResource AppTenue}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="11"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="Margin" Value="0,14,0,9"/>
  </Style>

  <Style x:Key="AppCardExpander" TargetType="Expander">
    <Setter Property="Background" Value="{StaticResource AppCard}"/>
    <Setter Property="BorderBrush" Value="{StaticResource AppBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Foreground" Value="{StaticResource AppTexto}"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="Expander">
          <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                  BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="10">
            <DockPanel>
              <ToggleButton x:Name="tb" DockPanel.Dock="Top" Cursor="Hand"
                            IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="Transparent" Padding="14,11">
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/>
                          <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <ContentPresenter Grid.Column="0" VerticalAlignment="Center"/>
                        <Path x:Name="arr" Grid.Column="1" VerticalAlignment="Center" Margin="10,0,0,0"
                              Data="M0,0 L8,8 L16,0" Stroke="#7DA792" StrokeThickness="2" Fill="Transparent"
                              RenderTransformOrigin="0.5,0.5"/>
                      </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsChecked" Value="True">
                        <Setter TargetName="arr" Property="RenderTransform">
                          <Setter.Value><RotateTransform Angle="180"/></Setter.Value>
                        </Setter>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
                <ContentPresenter ContentSource="Header"/>
              </ToggleButton>
              <Border x:Name="body" DockPanel.Dock="Bottom" Padding="14,0,14,12" Visibility="Collapsed"
                      BorderBrush="{StaticResource AppBordeSutil}" BorderThickness="0,1,0,0">
                <ContentPresenter/>
              </Border>
            </DockPanel>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsExpanded" Value="True">
              <Setter TargetName="body" Property="Visibility" Value="Visible"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="AppInputBox" TargetType="TextBox">
    <Setter Property="Background" Value="{StaticResource AppInput}"/>
    <Setter Property="Foreground" Value="{StaticResource AppTexto}"/>
    <Setter Property="BorderBrush" Value="{StaticResource AppBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
  </Style>

  <Style x:Key="AppInputMono" TargetType="TextBox" BasedOn="{StaticResource AppInputBox}">
    <Setter Property="FontFamily" Value="DM Mono, Consolas"/>
  </Style>

  <Style x:Key="AppBtnPrimary" TargetType="Button">
    <Setter Property="Background" Value="{StaticResource AppAccent}"/>
    <Setter Property="Foreground" Value="{StaticResource AppAccentDeep}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontWeight" Value="700"/>
    <Setter Property="FontSize" Value="13"/>
    <Setter Property="Padding" Value="10,8"/>
    <Setter Property="BorderThickness" Value="0"/>
    <Setter Property="Cursor" Value="Hand"/>
  </Style>

  <Style x:Key="AppChip" TargetType="RadioButton">
    <Setter Property="Foreground" Value="{StaticResource AppTexto2}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Margin" Value="3,0"/>
    <Setter Property="Padding" Value="13,5"/>
    <Setter Property="Cursor" Value="Hand"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="RadioButton">
          <Border x:Name="chip" CornerRadius="20" Padding="{TemplateBinding Padding}"
                  Background="{StaticResource AppChipBg}" BorderBrush="{StaticResource AppBorde}" BorderThickness="1">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="chip" Property="Background" Value="{StaticResource AppAccent}"/>
              <Setter Property="Foreground" Value="{StaticResource AppAccentDeep}"/>
              <Setter Property="FontWeight" Value="600"/>
              <Setter TargetName="chip" Property="Effect">
                <Setter.Value>
                  <DropShadowEffect Color="#5EAE87" BlurRadius="12" ShadowDepth="0" Opacity="0.45"/>
                </Setter.Value>
              </Setter>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <!-- ComboBox DEFAULT (sin x:Key: aplica a TODOS los ComboBox). WPF por default pinta el popup
       con colores de sistema (fondo blanco), lo que dejaba el contenido ilegible (texto claro sobre
       blanco). Aca se estila el ToggleButton, el item seleccionado y el Popup con la paleta de la app. -->
  <Style x:Key="AppComboToggle" TargetType="ToggleButton">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ToggleButton">
          <Border x:Name="cbBorder" Background="{StaticResource AppInput}" BorderBrush="{StaticResource AppBorde}"
                  BorderThickness="1" CornerRadius="4">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <Path x:Name="cbArrow" Grid.Column="1" Margin="0,0,8,0" VerticalAlignment="Center"
                    Data="M0,0 L4,4 L8,0 Z" Fill="#7DA792"/>
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="cbBorder" Property="BorderBrush" Value="{StaticResource AppAccent}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBox">
    <Setter Property="Background" Value="{StaticResource AppInput}"/>
    <Setter Property="Foreground" Value="{StaticResource AppTexto}"/>
    <Setter Property="BorderBrush" Value="{StaticResource AppBorde}"/>
    <Setter Property="BorderThickness" Value="1"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="6,4"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBox">
          <Grid>
            <ToggleButton x:Name="ToggleButton" Style="{StaticResource AppComboToggle}"
                          Focusable="False" ClickMode="Press"
                          IsChecked="{Binding IsDropDownOpen, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"/>
            <ContentPresenter x:Name="ContentSite" IsHitTestVisible="False" Margin="{TemplateBinding Padding}"
                              VerticalAlignment="Center" HorizontalAlignment="Left"
                              Content="{TemplateBinding SelectionBoxItem}"
                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
            <Popup x:Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
              <Border x:Name="DropDownBorder" MinWidth="{TemplateBinding ActualWidth}"
                      MaxHeight="{TemplateBinding MaxDropDownHeight}"
                      Background="{StaticResource AppCard}" BorderBrush="{StaticResource AppBorde}"
                      BorderThickness="1" CornerRadius="4">
                <ScrollViewer SnapsToDevicePixels="True">
                  <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained"/>
                </ScrollViewer>
              </Border>
            </Popup>
          </Grid>
          <ControlTemplate.Triggers>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="{StaticResource AppTexto3}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style TargetType="ComboBoxItem">
    <Setter Property="Background" Value="Transparent"/>
    <Setter Property="Foreground" Value="{StaticResource AppTexto}"/>
    <Setter Property="FontFamily" Value="Space Grotesk, Segoe UI"/>
    <Setter Property="FontSize" Value="12"/>
    <Setter Property="Padding" Value="8,5"/>
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="ComboBoxItem">
          <Border x:Name="itemBorder" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}"
                  CornerRadius="3">
            <ContentPresenter/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
              <Setter TargetName="itemBorder" Property="Background" Value="{StaticResource AppChipBg}"/>
              <Setter Property="Foreground" Value="{StaticResource AppAccentClaro}"/>
            </Trigger>
            <Trigger Property="IsSelected" Value="True">
              <Setter TargetName="itemBorder" Property="Background" Value="{StaticResource AppAccent}"/>
              <Setter Property="Foreground" Value="{StaticResource AppAccentDeep}"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>
</Window.Resources>
'@
}
